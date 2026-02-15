# Yugo

**Motor de automatización conductual para Android — macros con consecuencias reales**

<div align="center">

![Android](https://img.shields.io/badge/Android-10%2B-3DDC84?style=flat&logo=android)
![Flutter](https://img.shields.io/badge/Flutter-Latest-02569B?style=flat&logo=flutter)
![Kotlin](https://img.shields.io/badge/Kotlin-2.2.20-7F52FF?style=flat&logo=kotlin)

[Características](#características) • [Instalación](#instalación) • [Uso](#cómo-funciona) • [FAQ](#preguntas-frecuentes)

</div>

---

## ¿Qué es Yugo?

Yugo es un **motor de automatización conductual** inspirado en MacroDroid, especializado en hábitos y disciplina mediante macros con estructura **Trigger → Condition → Action**. La app es **solo Android** y funciona **100% local**: Flutter es la UI y la lógica vive en Android (Room + servicios nativos).

**Filosofía**: consecuencias reales, sin gamificación ni estadísticas innecesarias. La automatización es el producto.

---

## ✨ Características

### ⚙️ Motor de Macros
- **Trigger → Condition → Action** como paradigma unificado
- **Macros de hábito** con estado persistente (racha, reincidencia)
- **Macros de disciplina** contextuales (sin hábito asociado)
- **Acciones reales**: bloquear, aliviar, extender, desbloquear

### 🕒 Bloqueos y Control
- **Cuotas diarias y semanales** por app
- **Bloqueos por horario** (rangos con días)
- **Bloqueos por fecha** (periodos con hora)
- **Overlay + fallback** para bloqueo efectivo

### 🧠 Disciplina Contextual
- Triggers por uso, horario, batería o inactividad
- Bloqueo dinámico según condiciones
- Plantillas para crear disciplina rápida

### 📚 Biblioteca de Macros
- Guardar, reutilizar y clonar macros
- Categorización y tags
- Import/Export con validación profunda de esquema

### 🔐 Seguridad
- **Modo Administrador** con PIN
- Bloqueo temporal por intentos fallidos
- Sin recuperación del PIN (decisión consciente)

---

## 📱 Requisitos

- **Android 10+** (API 29+)
- Dispositivo físico recomendado
- ~50MB de espacio

### Permisos necesarios

| Permiso | Criticidad | Propósito |
|---------|-----------|-----------|
| Usage Stats | **CRÍTICO** | Tracking de uso real |
| Accessibility Service | **CRÍTICO** | Bloqueo/overlay efectivo |
| Display over other apps | RECOMENDADO | Overlay de bloqueo |
| Ignore Battery Optimizations | RECOMENDADO | Servicio estable |

---

## 🚀 Instalación

### Opción 1: Compilar desde código

```bash
flutter pub get
flutter run --release
```

**Requisitos de desarrollo**:
- Flutter SDK (stable)
- JDK 17+
- Gradle 8.14+

---

## 🎮 Cómo Funciona

### Setup Inicial (< 2 minutos)

1. **Permisos**: habilita UsageStats + Accessibility + Overlay
2. **Bloqueos**: define límites diarios/semanales o bloqueos por tiempo/fecha
3. **Macros**: crea hábitos o disciplina con el editor avanzado
4. **Opcional**: configura PIN admin

### Ejemplo: Macro de Hábito

```
Trigger: 23:59 (fin de día)
Condition: Instagram > 30 min
Action: Bloquear Instagram 24h + aumentar reincidencia
```

### Ejemplo: Disciplina Contextual

```
Trigger: App abierta (Instagram)
Condition: Lunes-Viernes, 09:00-18:00
Action: Bloquear hasta fin de rango
```

---

## 🛡️ Privacidad y Seguridad

### Lo que Yugo HACE
- Procesa uso de apps **localmente** (UsageStats)
- Guarda configuración en Room (SQLite)
- Bloquea apps sin enviar datos externos

### Lo que Yugo NO HACE
- No requiere cuenta
- No envía datos a servidores
- No usa analytics
- No depende de Internet

---

## 🗺️ Roadmap (resumen)

### ✅ Implementado
- Editor avanzado de macros
- Modo disciplina con plantillas
- Biblioteca de macros + import/export
- Bloqueos por cuota/horario/fecha

### ⏳ En curso
- Pulido de nomenclatura y contratos
- Estabilidad y optimización

---

## 🤝 Contribuir

Proyecto en desarrollo individual. Si tienes bugs o sugerencias, abre un issue con detalles y logs relevantes.

---

## 📄 Licencia

MIT License. Ver `LICENSE`.

---

<div align="center">

**Yugo — Automatización real, consecuencias reales**

</div>
