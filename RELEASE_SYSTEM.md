# LibreDrop Release System

Este documento describe cómo usar el sistema de releases automatizado de LibreDrop.

## 🚀 Proceso de Release

### 1. Preparación Local
```bash
# Verificar el entorno
./scripts/check_environment.sh

# Ejecutar tests
flutter test

# Preparar nueva versión
./scripts/prepare_release.sh
```

### 2. Release Automático
Una vez que hagas push del tag, GitHub Actions:
- ✅ Ejecuta todos los tests
- ✅ Compila para todas las plataformas
- ✅ Crea instaladores nativos
- ✅ Sube binarios a GitHub Releases
- ✅ Actualiza la información del website

### 3. Verificación
- Verifica que el release aparezca en: https://github.com/pablojavier/libredrop/releases
- Confirma que el website detecte la nueva versión
- Testa los binarios descargados

## 📝 Scripts Disponibles

### `scripts/prepare_release.sh`
Prepara una nueva versión:
- Actualiza versión en `pubspec.yaml`
- Actualiza `lib/constants/app_info.dart`
- Ejecuta tests
- Actualiza `CHANGELOG.md`
- Crea commit y tag
- Hace push automático

### `scripts/build_all_platforms.sh`
Compila para todas las plataformas localmente:
- Android (APK multi-arch)
- Windows (ZIP)
- macOS (ZIP) 
- Linux (tar.gz)
- Web (tar.gz)

### `scripts/check_environment.sh`
Verifica el entorno de desarrollo:
- Flutter installation
- Git configuration
- Project structure
- GitHub Actions setup

### `scripts/clean_builds.sh`
Limpia builds y archivos temporales

## 🔄 GitHub Actions

### CI Workflow (`.github/workflows/ci.yml`)
Se ejecuta en cada push y PR:
- Tests automatizados
- Análisis de código
- Build de verificación
- Coverage report

### Release Workflow (`.github/workflows/release.yml`)
Se ejecuta cuando se crea un tag `v*.*.*`:
- Compila para Android, Windows, macOS, Linux
- Crea instaladores nativos
- Sube binarios a GitHub Releases
- Genera release notes automáticas

## 🌐 Integración Website

El archivo `website_integration/platform-detect.js` debe copiarse al website para:
- Detectar automáticamente la plataforma del usuario
- Mostrar el botón de descarga correcto
- Obtener la última versión desde GitHub API
- Actualizar links de descarga automáticamente

### Uso en el website:
```html
<script src="assets/js/platform-detect.js"></script>

<!-- Botón de descarga automático -->
<a href="#" id="download-auto" class="btn btn-primary">
    <span class="btn-text">Download LibreDrop</span>
    <span class="btn-version">v1.0.0</span>
    <span class="btn-size"></span>
</a>
```

## 🎯 Versionado

Usamos [Semantic Versioning](https://semver.org/):
- `MAJOR.MINOR.PATCH` (e.g., `1.2.3`)
- Major: Breaking changes
- Minor: New features (backwards compatible)
- Patch: Bug fixes

## 🔧 Personalización

### Cambiar información del proyecto:
Edita `lib/constants/app_info.dart`

### Modificar platforms:
Edita los workflows en `.github/workflows/`

### Personalizar release notes:
Edita la sección de release notes en `release.yml`

## 🆘 Troubleshooting

### Build falla en GitHub Actions:
1. Verifica que los tests pasen localmente
2. Revisa los logs en GitHub Actions
3. Asegúrate de que la versión en `pubspec.yaml` sea válida

### Website no detecta nueva versión:
1. Verifica que el release esté público en GitHub
2. Comprueba la consola del navegador para errores de API
3. Asegúrate de que `platform-detect.js` esté actualizado

### No se pueden crear tags:
1. Verifica permisos de Git
2. Asegúrate de estar en la branch `main`
3. Confirma que no exista ya el tag

## 📞 Soporte

Para problemas con el sistema de releases:
1. Revisa este documento
2. Consulta los logs de GitHub Actions
3. Crea un issue en el repositorio
