from pathlib import Path
import hashlib, re, subprocess, sys, zipfile

workspace = Path.cwd()
source_root = workspace / "agent-v0.5.3"
parts_dir = workspace / "agent" / "patch-parts"
parts = [parts_dir / f"part-{i:02d}.txt" for i in range(1, 9)]
if not all(p.exists() for p in parts):
    raise SystemExit("No están todos los segmentos del parche 0.5.4.")

patch = "".join(p.read_text(encoding="utf-8") for p in parts)
patch = patch.replace("\r\n", "\n").replace("\r", "\n")
patch_hash = hashlib.sha256(patch.encode("utf-8")).hexdigest()
expected = "1ee1be7dc4525ce712908b2470578051555ae6663a2fbafd70889c404b755e6d"
print("Parche 0.5.4 SHA256:", patch_hash)
if patch_hash != expected:
    raise SystemExit("La suma del parche 0.5.4 no coincide.")

# The original Inno Setup hunk was generated against a slightly different line
# context. Keep its known-good 0.5.3 cleanup/upgrade logic and bump its version
# metadata below; apply every C# runtime, sync, MAC, test and build change.
blocks = re.split(r"(?=^--- a/)", patch, flags=re.MULTILINE)
patch_without_iss = "".join(
    block for block in blocks
    if not block.startswith("--- a/agent-v0.5.3/AandTPrinterAgent.iss")
)
patch_path = workspace / "agent-v0.5.4-no-iss.patch"
patch_path.write_text(patch_without_iss, encoding="utf-8", newline="\n")

for args in [
    ["git", "apply", "--check", "-p2", str(patch_path)],
    ["git", "apply", "-p2", str(patch_path)],
]:
    result = subprocess.run(args, cwd=source_root, text=True, capture_output=True)
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr)
    if result.returncode:
        raise SystemExit(f"Error aplicando cambios del agente 0.5.4: {result.returncode}")

# Version metadata for the installer; keep the tested 0.5.3 installer logic.
iss = source_root / "AandTPrinterAgent.iss"
text = iss.read_text(encoding="utf-8-sig")
text = text.replace('#define MyAppVersion "0.5.3"', '#define MyAppVersion "0.5.4"')
text = text.replace("VersionInfoVersion=0.5.3.0", "VersionInfoVersion=0.5.4.0")
text = text.replace("VersionInfoProductVersion=0.5.3", "VersionInfoProductVersion=0.5.4")
text = text.replace("OutputBaseFilename=Instalar_ATPrinterAgent_v0.5.3", "OutputBaseFilename=Instalar_ATPrinterAgent_v0.5.4")
iss.write_text(text, encoding="utf-8-sig", newline="\n")

# Install the new visual layer without touching runtime/discovery/sync code.
theme_source = workspace / "agent" / "rebuild" / "ModernTheme.cs"
theme_target = source_root / "src" / "UI" / "ModernTheme.cs"
theme_target.write_text(theme_source.read_text(encoding="utf-8"), encoding="utf-8", newline="\n")

main_form = source_root / "src" / "UI" / "MainForm.cs"
mf = main_form.read_text(encoding="utf-8-sig")
needle = "        BuildTray();\n\n        _runtime.StatusChanged"
replacement = "        BuildTray();\n        ModernTheme.Apply(this);\n\n        _runtime.StatusChanged"
if needle not in mf:
    raise SystemExit("No se encontró el punto seguro para aplicar el tema a MainForm.")
mf = mf.replace(needle, replacement, 1)
main_form.write_text(mf, encoding="utf-8-sig", newline="\n")

# Accurate release notes: this build retains the existing optional clean-install
# prompt; accepting it removes old local A&T data, declining preserves settings.
# Use the verifier matching the 0.5.4 installer name and version.
verifier_source = workspace / "agent" / "verify-build.ps1"
verifier_target = source_root / "verify-build.ps1"
if not verifier_source.exists():
    raise SystemExit("Falta agent/verify-build.ps1 del repositorio.")
verifier_target.write_text(verifier_source.read_text(encoding="utf-8"), encoding="utf-8", newline="\\n")

notes = """## A&T Printix Agent 0.5.4 — Futuristic Edition

### Interfaz
- Nueva identidad A&T Printix con interfaz oscura premium y acentos cian.
- Alternancia entre modo oscuro y modo claro.
- Inventario y controles con contraste, espaciado y tipografía renovados.
- La bandeja del sistema, el arranque discreto y el comportamiento de cierre se conservan.

### Lectura y sincronización
- Conserva el motor 0.5.3: descubrimiento Windows/USB y LAN, SNMP v1/v2c/v3,
  Printer-MIB, OIDs de fabricantes, seriales validados, contadores y consumibles.
- Envía MAC normalizada y datos de lectura al panel.
- Emite y protege con DPAPI un token remoto por instalación.
- Amplía el filtro de colas virtuales y mantiene la deduplicación.
- Actualiza el agente contra A&T Printix/Supabase usando el contrato actual.

### Instalación
- El instalador no incluye serial de proyecto. En el primer inicio se introduce
  el serial correspondiente a la empresa/proyecto.
- Se conserva el diálogo conocido de actualización o instalación limpia:
  aceptar limpia datos locales A&T; rechazar conserva la instalación anterior.
- No se eliminan proyectos, seriales registrados ni históricos de Supabase.
- Las actualizaciones remotas siguen conservando activación/configuración.

### Verificación
- Se ejecutan las pruebas automáticas antes de publicar artefactos.
- Instaladores autocontenidos Windows x64 y x86, con SHA-256 de cada instalador.
"""
(source_root / "RELEASE_NOTES_0.5.4.md").write_text(notes, encoding="utf-8")

readme = """A&T Printix Agent 0.5.4 — Futuristic Edition

Agente Windows de A&T Printix para descubrir, identificar y monitorear impresoras.
Incluye interfaz oscura premium con modo claro, arranque discreto y bandeja del sistema.

INSTALACIÓN
1. Ejecutar Instalar_ATPrinterAgent_v0.5.4.exe como administrador.
2. En el primer inicio, pegar el serial del proyecto generado en el panel A&T Printix.
3. Pulsar Activar serial y configurar las IP/rangos si se necesita escaneo LAN.
4. El agente trabaja en segundo plano y puede abrirse desde el icono junto al reloj.

El serial no está precargado en el EXE ni en el instalador.
La activación se valida con printer-agent-sync en Supabase.
Configuración local: %LOCALAPPDATA%\\ATPrinterAgent\\config.json

LECTURA
- Windows/USB y descubrimiento de red.
- SNMP v1/v2c/v3, Printer-MIB y OIDs de fabricante.
- Número de serie y contadores solo se envían cuando fueron leídos y validados.
- Si la impresora no publica un dato, permanece vacío; el agente no inventa seriales ni contadores.

SEGURIDAD Y COMPATIBILIDAD
- Clave publicable de Supabase en el agente; nunca service_role.
- Token remoto de instalación protegido con DPAPI.
- Mantener disponibles las Edge Functions actuales de A&T Printix.
"""
(source_root / "README.txt").write_text(readme, encoding="utf-8")

# Confirm the executable carries no project activation serial.
contracts = (source_root / "src" / "Contracts" / "AgentContracts.cs").read_text(encoding="utf-8-sig")
if not re.search(r'public string Serial \{ get; set; \} = ""', contracts):
    raise SystemExit("No se pudo verificar el valor serial vacío por defecto.")
if "agent_token" not in contracts and "AgentToken" not in contracts:
    raise SystemExit("Falta el campo de token remoto en los contratos del agente.")

print("Base 0.5.4 + tema futurista aplicada correctamente.")
