# 🖼️ img2monitor

<div align="center">
  
  ![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
  ![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B.svg)
  ![Android](https://img.shields.io/badge/Android-10+-3DDC84.svg)
  ![License](https://img.shields.io/badge/license-MIT-green.svg)

  **Una aplicación Android para mostrar imágenes personalizadas en tu segundo monitor**  
  *Ideal para iglesias, presentaciones, karaoke y señalización digital*

  [Características](#-características) • 
  [Cómo funciona](#-cómo-funciona) • 
  [Instalación](#-instalación) • 
  [Casos de uso](#-casos-de-uso) • 
  [Contribuir](#-contribuciones)

</div>

---

## 📋 Descripción

**img2monitor** es una aplicación desarrollada con Flutter que resuelve un problema común: **mostrar contenido estático en una pantalla secundaria mientras usas tu teléfono de forma privada**.

¿Necesitas que un monitor externo muestre un versículo bíblico, la letra de una canción o el logotipo de tu empresa, mientras en tu teléfono ves tus notas o controlas la presentación? img2monitor te permite seleccionar cualquier imagen de tu galería y establecerla como fondo exclusivo para tu segunda pantalla, sin reflejar lo que haces en tu dispositivo principal.

## ✨ Características

- 🎯 **Fondo dedicado**: Establece cualquier imagen como fondo exclusivo para tu monitor externo
- 🔒 **Privacidad garantizada**: Lo que haces en tu teléfono no se refleja en la pantalla grande
- 🖼️ **Selector de imágenes integrado**: Elige fotos directamente desde tu galería
- 📱 **Interfaz intuitiva**: Diseño limpio y fácil de usar gracias a Flutter
- 🔄 **Modo de proyección por app**: Compatible con "compartir solo esta app" de Android 14+
- 🎨 **Vista previa en tiempo real**: Ve cómo se verá la imagen antes de proyectarla
- 📂 **Soporte multi-formato**: Compatible con JPG, PNG, BMP y otros formatos comunes

## 🚀 Cómo funciona

```mermaid
graph LR
    A[Conectar teléfono al monitor] --> B[Abrir img2monitor]
    B --> C[Seleccionar imagen de la galería]
    C --> D[La app muestra la imagen]
    D --> E[Configurar proyección "solo esta app"]
    E --> F[¡Listo! Monitor muestra la imagen]