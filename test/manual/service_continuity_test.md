# 🧪 Test Manual - Continuidad del Servicio

## Objetivo
Verificar que el servicio de foreground sobrevive a:
- Cierre de la app
- Reinicio del dispositivo
- Modo Doze

---

## ⚙️ Configuración inicial

### Windows (PowerShell)
Los comandos usan `Select-String` o `findstr` en lugar de `grep`.

---

## Test 1: Sobrevivir al cierre de la app

### Pasos:
1. Abrir la app Yugo
2. Verificar que aparece la notificación "Yugo está activo"
3. **Cerrar la app** (swipe desde recientes)
4. Verificar que la notificación **permanece visible**
5. Abrir panel de notificaciones
6. Tocar la notificación de Yugo

### Resultado esperado:
✅ Notificación permanece después de cerrar la app
✅ Al tocar la notificación, la app se abre
✅ No hay crashes en logcat

### Comando para verificar:

**Windows (PowerShell):**
```powershell
adb logcat | Select-String "MacroExecutorService"
```

**macOS/Linux:**
```bash
adb logcat | grep "MacroExecutorService"
```

---

## Test 2: Sobrevivir a reinicio del dispositivo

### Pasos:
1. Abrir la app Yugo
2. Verificar que aparece la notificación
3. **Reiniciar el dispositivo**
4. Esperar que el dispositivo inicie completamente
5. Verificar el panel de notificaciones

### Resultado esperado:
✅ Notificación reaparece automáticamente después del boot
✅ No es necesario abrir la app
✅ BootReceiver ejecutado correctamente

### Comando para verificar:

**Windows (PowerShell):**
```powershell
adb logcat | Select-String "YugoBootReceiver"
```

**macOS/Linux:**
```bash
adb logcat | grep "YugoBootReceiver"
```

Debe mostrar:
```
YugoBootReceiver: Device boot completed, restarting service...
YugoBootReceiver: MacroExecutorService started successfully
```

---

## Test 3: Verificar estado del servicio

### Pasos:
1. Conectar dispositivo vía ADB
2. Ejecutar comando:

**Windows (PowerShell):**
```powershell
adb shell dumpsys activity services | Select-String "MacroExecutorService"
```

**macOS/Linux:**
```bash
adb shell dumpsys activity services | grep MacroExecutorService
```

### Resultado esperado:
```
* ServiceRecord{...} u0 com.example.yugo/.services.MacroExecutorService
  app=ProcessRecord{...}
  foreground=true
```

---

## Test 4: Optimización de batería

### Pasos:
1. Ir a: **Configuración > Aplicaciones > Yugo**
2. Buscar "Batería" o "Optimización de batería"
3. Verificar estado actual

### Resultado esperado:
- Si está **optimizada**: Servicio puede ser matado en Doze
- Si está **no optimizada**: Servicio sobrevivirá

### Para desactivar optimización:
1. Configuración > Batería > Optimización de batería
2. Cambiar filtro a "Todas las apps"
3. Buscar "Yugo"
4. Seleccionar "No optimizar"

---

## Test 5: Modo Doze simulado

### Pasos:
1. Activar opciones de desarrollador en el dispositivo
2. Conectar vía ADB
3. Ejecutar comandos (iguales en Windows y Unix):
```bash
# Forzar Doze mode
adb shell dumpsys deviceidle force-idle

# Esperar 30 segundos

# Verificar si el servicio sigue vivo
adb shell dumpsys activity services | Select-String "MacroExecutorService"  # Windows
adb shell dumpsys activity services | grep MacroExecutorService             # Unix

# Salir de Doze
adb shell dumpsys deviceidle unforce
```

### Resultado esperado:
✅ Si optimización está deshabilitada: servicio sobrevive
⚠️ Si optimización está habilitada: servicio puede ser matado

---

## Test 6: Logs del servicio

### Comando para ver logs en tiempo real:

**Windows (PowerShell):**
```powershell
adb logcat | Select-String "MacroExecutorService|YugoBootReceiver|MacroChannel"
```

### Eventos a observar:
- `Service onCreate()`
- `Service onStartCommand()`
- `Starting foreground service...`
- `Foreground service started successfully`
- `Service onDestroy()` (solo si se detiene manualmente)

---

## 🪟 Comandos adicionales para Windows

### Ver solo errores:
```powershell
adb logcat *:E | Select-String "yugo"
```

### Limpiar logs y empezar de nuevo:
```powershell
adb logcat -c
adb logcat | Select-String "Yugo"
```

### Guardar logs en archivo:
```powershell
adb logcat | Select-String "MacroExecutorService" | Out-File -FilePath logs.txt
```

### Ver logs de múltiples tags:
```powershell
adb logcat | Select-String "MacroExecutorService|BootReceiver|MainActivity"
```
