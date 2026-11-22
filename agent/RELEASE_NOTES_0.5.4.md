## A&T Printer Agent 0.5.4

### Instalación limpia con serial ingresado por el usuario

- El instalador no contiene ni preconfigura ningún serial de proyecto.
- Al encontrar una instalación anterior de A&T (línea 0.5.x o 0.4.x), pregunta si debe desinstalarla y borrar los datos locales antes de instalar.
- Responder **Sí** desinstala las versiones previas de A&T y elimina serial protegido, token, IPs/rangos, caché, tareas y arranque automático en los perfiles Windows detectados.
- Responder **No** cancela la instalación sin modificar la versión anterior.
- Después de instalar, la ventana se abre con el campo de serial vacío para que el usuario pegue el serial de su proyecto.
- No se eliminan proyectos, seriales registrados, inventario ni lecturas históricas de Supabase.
- Las actualizaciones silenciosas autorizadas desde el panel mantienen la configuración y la activación, para no romper el canal remoto.

### Lectura y sincronización

- Conserva el motor de lectura de la versión 0.5.3: Printer-MIB, SNMP v1/v2c/v3, OIDs de fabricantes, walk de tablas, validación de serial, contadores totales y consumibles.
- Corrige el mapeo de MAC: la dirección leída por SNMP se incluye ahora en el JSON que recibe A&T Printix.
- Añade token remoto individual: el servidor emite un token para la instalación nueva durante la primera sincronización; el agente lo almacena protegido con DPAPI y lo presenta al consultar comandos.
- Amplía el filtro de impresoras virtuales (Foxit, Evernote, PDF, XPS, OneNote y colas Fax exactas), sin descartar una multifunción física por contener la palabra Fax en el nombre del modelo.
- Corrige el actualizador para buscar las releases en `pepifer82-cyber/at-printix` y aceptar versiones `0.5.x`.

### Verificación

- Pruebas automáticas: validación de serial/MAC, transporte, filtros virtuales, mapeo de MAC, protección del token y versiones 0.x.
- El instalador se compila como ejecutable autocontenido para Windows x64 y x86.
- Si el entorno de compilación no tiene el certificado privado de firma de A&T, los binarios quedan sin firmar; las sumas SHA-256 se generan igualmente y se verifican antes de las actualizaciones.
