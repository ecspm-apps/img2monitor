import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:image_picker/image_picker.dart';
import 'package:presentation_displays/displays_manager.dart';
import 'package:presentation_displays/display.dart';
import 'package:presentation_displays/secondary_display.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  const fln.AndroidNotificationChannel channel = fln.AndroidNotificationChannel(
    'my_foreground', 
    'img2monitor Service', 
    description: 'Maintains projection engine alive in background',
    importance: fln.Importance.low,
  );
  
  final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        fln.AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'img2monitor',
      initialNotificationContent: 'Projection Engine is Ready',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
        autoStart: false,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Este Isolate vacío se queda atrapado en un bucle infinito gracias a 'isForegroundMode'. 
  // Garantiza que todo el paquete de la aplicación (incluyendo OverlayApp) no muera cuando el usuario haga Swipe Up.
}

// Entry point for the overlay window. Must be accessible globally.
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}

// Entry point for the secondary display. Required by presentation_displays on Android.
@pragma("vm:entry-point")
void secondaryDisplayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SecondaryApp());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  
  runApp(const MyApp());
}

class SecondaryApp extends StatelessWidget {
  const SecondaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Img2Monitor Presentation',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: 'presentation',
      onGenerateRoute: (settings) {
        if (settings.name == 'presentation') {
          return MaterialPageRoute(builder: (context) => const SecondaryScreen());
        }
        return MaterialPageRoute(builder: (context) => const SecondaryScreen());
      },
    );
  }
}

// Store global theme state
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Img2Monitor',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          themeMode: currentMode,
          initialRoute: '/',
          onGenerateRoute: (settings) {
            if (settings.name == 'presentation') {
              return MaterialPageRoute(builder: (context) => const SecondaryScreen());
            }
            return MaterialPageRoute(builder: (context) => const MainAppScreen());
          },
        );
      },
    );
  }
}

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> with WidgetsBindingObserver {
  DisplayManager displayManager = DisplayManager();
  List<Display?> displays = [];
  bool isPresentationActive = false;
  String? currentImagePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startOverlay();
    });

    displayManager.connectedDisplaysChangedStream?.listen((event) {
      _refreshDisplays();
    });

    _refreshDisplays();

    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == "PRESENTATION_STARTED" && mounted) {
        setState(() { isPresentationActive = true; });
        _showToast("Projection Active in Background");
      } else if (event == "PRESENTATION_STOPPED" && mounted) {
        setState(() { isPresentationActive = false; });
        _showToast("Projection Stopped in Background");
      }
    });
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _refreshDisplays() async {
    try {
      final values = await displayManager.getDisplays();
      setState(() {
        displays.clear();
        if (values != null) {
          displays.addAll(values);
        }
      });
      // Comentamos el Toast automático al iniciar para no molestar la UI, 
      // pero lo lanzaremos cuando el usuario accione cosas manualmente.
    } catch (e) {
      print(e);
    }
  }

  Future<void> _togglePresentation() async {
    try {
      if (displays.isEmpty || displays.length < 2) {
        _showToast("Error: No secondary displays found. Count: ${displays.length}");
        return; 
      }
      _showToast("Sending Toggle Command to Background Overlay Daemon...");
      await FlutterOverlayWindow.shareData("TOGGLE_PRESENTATION");
    } catch (e) {
      _showToast("Exception: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startOverlay();
    }
  }

  Future<void> _requestPermissions() async {
    bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) {
      await FlutterOverlayWindow.requestPermission();
    }
  }

  Future<void> _startOverlay() async {
    bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }

    if (await FlutterOverlayWindow.isActive()) {
      return;
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: "Img2Monitor",
      overlayContent: "Overlay is running",
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.none,
      alignment: OverlayAlignment.center,
      height: 120, // Reduced height for a smaller floating button
      width: 120,  // Reduced width
    );
  }

  Future<void> _pickAndShareImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      currentImagePath = image.path;
      // Send the image path to the overlay
      await FlutterOverlayWindow.shareData(image.path);
      // Ensure overlay is started after picking image
      _startOverlay();

      if (isPresentationActive) {
        await displayManager.transferDataToPresentation(image.path);
      }
    }
  }

  Future<void> _stopOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _clearImage() async {
    setState(() {
      currentImagePath = null;
    });
    await FlutterOverlayWindow.shareData("CLEAR");
    if (isPresentationActive) {
      await displayManager.transferDataToPresentation("CLEAR");
    }
    _showToast("Image cleared");
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Img2Monitor Control", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (_, ThemeMode currentMode, __) {
              return Row(
                children: [
                  Icon(currentMode == ThemeMode.light ? Icons.light_mode : Icons.dark_mode, size: 20),
                  Switch(
                    value: currentMode == ThemeMode.dark,
                    onChanged: (value) async {
                      themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isDarkMode', value);
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 24),
              isLandscape 
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildControlsCard("Overlay", Icons.layers)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildControlsCard("Image", Icons.image)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildControlsCard("Projection", Icons.monitor)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildControlsCard("Overlay", Icons.layers),
                        const SizedBox(height: 16),
                        _buildControlsCard("Image", Icons.image),
                        const SizedBox(height: 16),
                        _buildControlsCard("Projection", Icons.monitor),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 40, color: Colors.blueAccent),
            const SizedBox(height: 12),
            Text(
              displays.length >= 2 
                  ? "Secondary display ready" 
                  : "No secondary display found",
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: displays.length >= 2 ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Displays connected: ${displays.length}",
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard(String title, IconData icon) {
    List<Widget> buttons = [];

    if (title == "Overlay") {
      buttons = [
        _buildActionButton("Start Overlay", Icons.play_arrow, Colors.blue, _startOverlay),
        const SizedBox(height: 12),
        _buildActionButton("Stop Overlay", Icons.stop, Colors.red, _stopOverlay),
        const SizedBox(height: 12),
        _buildActionButton("Request Permissions", Icons.security, Colors.orange, _requestPermissions),
      ];
    } else if (title == "Image") {
      buttons = [
        _buildActionButton("Load Image", Icons.photo_library, Colors.purple, _pickAndShareImage),
        const SizedBox(height: 12),
        _buildActionButton("Clear Image", Icons.delete_sweep, Colors.grey.shade700, _clearImage),
        if (currentImagePath != null) ...[
          const SizedBox(height: 12),
          Text("Image selected", style: TextStyle(color: Colors.green.shade700, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
        ]
      ];
    } else if (title == "Projection") {
      buttons = [
        _buildActionButton(
          isPresentationActive ? "Stop Projection" : "Start Projection", 
          isPresentationActive ? Icons.videocam_off : Icons.videocam, 
          isPresentationActive ? Colors.red : Colors.green, 
          _togglePresentation
        ),
        const SizedBox(height: 12),
        _buildActionButton("Refresh Displays", Icons.refresh, Colors.teal, () {
          _refreshDisplays();
          _showToast("Display count updated");
        }),
      ];
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.black54),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            ...buttons,
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
    );
  }
}

// ==========================================
// OVERLAY WIDGET
// ==========================================

class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  String? _imagePath;
  bool _isTapped = false;
  bool _isPresentationActive = false;
  final DisplayManager displayManager = DisplayManager();

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == "TOGGLE_PRESENTATION") {
        _triggerDaemonProjectionToggle();
      } else if (event == "CLEAR") {
        setState(() {
          _imagePath = null;
        });
        if (_isPresentationActive) {
           displayManager.transferDataToPresentation("CLEAR");
        }
      } else if (event != null && event is String && event != "PRESENTATION_STARTED" && event != "PRESENTATION_STOPPED") {
        setState(() {
          _imagePath = event;
        });
        if (_isPresentationActive) {
           displayManager.transferDataToPresentation(event);
        }
      }
    });
  }

  Future<void> _triggerDaemonProjectionToggle() async {
    try {
      final displays = await displayManager.getDisplays();
      if (displays != null && displays.length >= 2) {
        final externalDisplay = displays.firstWhere((d) => d?.displayId != 0, orElse: () => displays[1]);
        if (externalDisplay != null) {
          if (_isPresentationActive) {
            await displayManager.hideSecondaryDisplay(displayId: externalDisplay.displayId!);
            _isPresentationActive = false;
            FlutterOverlayWindow.shareData("PRESENTATION_STOPPED");
          } else {
            await displayManager.showSecondaryDisplay(displayId: externalDisplay.displayId!, routerName: "presentation");
            _isPresentationActive = true;
            FlutterOverlayWindow.shareData("PRESENTATION_STARTED");
            if (_imagePath != null) {
              Future.delayed(const Duration(milliseconds: 1000), () {
                displayManager.transferDataToPresentation(_imagePath);
              });
            }
          }
        }
      }
    } catch (e) {
      print("Daemon Overlay Toggle Error: $e");
    }
  }

  void _handleTap() {
    setState(() {
      _isTapped = true;
    });
    
    // Process completely internally, no reliance on main App Isolate
    _triggerDaemonProjectionToggle();
    
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isTapped = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent, // Important for overlay
        body: Center(
          child: GestureDetector(
            onTap: _handleTap,
            child: Opacity(
              opacity: _isTapped ? 0.8 : 0.4, // Mas visible cuando se toca
              child: Container(
                width: 100, // Reduced size
                height: 100, // Reduced size
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: _isTapped ? Border.all(color: Colors.blueAccent, width: 4) : null,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: ClipOval(
                  child: _imagePath != null
                      ? Image.file(
                          File(_imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.broken_image, size: 50, color: Colors.grey);
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SECONDARY SCREEN WIDGET
// ==========================================

class SecondaryScreen extends StatefulWidget {
  const SecondaryScreen({super.key});

  @override
  State<SecondaryScreen> createState() => _SecondaryScreenState();
}

class _SecondaryScreenState extends State<SecondaryScreen> {
  String? _imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Typical background for presentation displays
      body: SecondaryDisplay(
        callback: (dynamic argument) {
          if (argument == "CLEAR") {
            setState(() {
              _imagePath = null;
            });
          } else if (argument != null && argument is String) {
            setState(() {
              _imagePath = argument;
            });
          }
        },
        child: Center(
          child: _imagePath != null
              ? Image.file(
                  File(_imagePath!),
                  fit: BoxFit.contain, // Show full image on screen
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.broken_image, size: 100, color: Colors.white);
                  },
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

