/// Ambientes de servidor conocidos para la aplicación móvil.
///
/// Centraliza todas las direcciones IP y URLs en un único lugar conforme a
/// las reglas de arquitectura (CA-01, CA-02).
enum AmbienteServidor {
  produccion(
    id: 'produccion',
    nombre: 'Producción Cloud (censo.willdeveloper.site)',
    descripcion: 'Servidor oficial en la nube (Cloudflare)',
    url: 'https://censo.willdeveloper.site',
  ),
  equipo(
    id: 'equipo',
    nombre: 'Equipo local (192.168.66.84)',
    descripcion: 'IP Ethernet del host de desarrollo',
    url: 'http://192.168.66.84:3001',
  ),
  wifi(
    id: 'wifi',
    nombre: 'Red Wi-Fi (192.168.100.104)',
    descripcion: 'IP Wi-Fi del host de desarrollo',
    url: 'http://192.168.100.104:3001',
  ),
  usb(
    id: 'usb',
    nombre: 'Cable USB (localhost:3001)',
    descripcion: 'Túnel ADB directo por cable USB',
    url: 'http://localhost:3001',
  ),
  emulador(
    id: 'emulador',
    nombre: 'Emulador Android (10.0.2.2)',
    descripcion: 'Host local visto desde el emulador',
    url: 'http://10.0.2.2:3001',
  ),
  hospital(
    id: 'hospital',
    nombre: 'Hospital CPS (192.168.66.84)',
    descripcion: 'Red hospitalaria CPS',
    url: 'http://192.168.66.84:3001',
  ),
  oficinas(
    id: 'oficinas',
    nombre: 'Oficinas Administrativas',
    descripcion: 'Red de oficinas administrativas',
    url: 'http://192.168.100.104:3001',
  ),
  personalizado(
    id: 'personalizado',
    nombre: 'Servidor Personalizado',
    descripcion: 'IP o URL configurada manualmente',
    url: '',
  );

  const AmbienteServidor({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.url,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final String url;

  static const String ejemploPersonalizado = 'http://192.168.1.50:3001';
  static const String hintPersonalizado = 'http://192.168.66.84:3001';

  static AmbienteServidor desdeId(String id) {
    for (final a in AmbienteServidor.values) {
      if (a.id == id) return a;
    }
    return AmbienteServidor.equipo;
  }

  static AmbienteServidor desdeUrl(String url) {
    final u = url.trim().toLowerCase();
    for (final a in AmbienteServidor.values) {
      if (a == AmbienteServidor.personalizado) continue;
      if (a.url.toLowerCase() == u) return a;
    }
    return AmbienteServidor.personalizado;
  }
}
