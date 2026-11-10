import '../../../core/network/image_url.dart';

/// Modelo de categoria de producto.
///
/// El backend NO expone `GET /categories` publico (`/products/categories` es
/// ADMIN). La web replica una lista estatica en `src/data/products.ts` y la
/// enriquece con `GET /products/counts` (`{total, byCategory: {slug: n}}`).
/// Los ids de esa lista **coinciden** con los ids de la tabla `Category` de la
/// BD (verificado: `?categoryId=impresion` filtra), por eso `id` y `slug` son
/// el mismo valor.
class Category {
  const Category({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.icon,
    this.productCount,
    this.subcategories = const [],
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString(),
      description: json['description']?.toString(),
      // Normalizar URL relativa de icono (/uploads/...) a absoluta.
      icon: resolveImageUrl(json['icon']?.toString()),
      productCount:
          json['productCount'] as int? ?? json['_count']?['products'] as int?,
      subcategories: (json['subcategories'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  /// Id de la categoria en la BD (para `GET /products?categoryId=`).
  final String id;
  final String name;
  final String? slug;
  final String? description;
  /// URL absoluta del icono (solo categorias provenientes de la BD).
  final String? icon;
  final int? productCount;
  final List<String> subcategories;

  /// Valor a usar en `?categoryId=` (id y slug coinciden).
  String get filterId => slug ?? id;
}

/// Catalogo estatico de categorias — replica de `productCategories` de la web
/// (`src/data/products.ts`). Orden y textos identicos.
const List<Category> productCategories = [
  Category(
    id: 'impresion',
    slug: 'impresion',
    name: 'Impresión e Identificación',
    description:
        'Soluciones completas de impresión, escáner y consumibles para identificación automática.',
  ),
  Category(
    id: 'movilidad',
    slug: 'movilidad',
    name: 'Movilidad Empresarial',
    description:
        'Terminales móviles, tablets y dispositivos RFID para optimizar operaciones empresariales.',
  ),
  Category(
    id: 'computo',
    slug: 'computo',
    name: 'Tecnología & Cómputo',
    description:
        'Equipos de cómputo, accesorios y soluciones tecnológicas para todas las necesidades.',
  ),
  Category(
    id: 'seguridad',
    slug: 'seguridad',
    name: 'Seguridad & Vigilancia',
    description:
        'Sistemas integrales de seguridad, videovigilancia y control de acceso.',
  ),
  Category(
    id: 'redes',
    slug: 'redes',
    name: 'Redes & Comunicación',
    description: 'Infraestructura de red, comunicaciones y conectividad empresarial.',
  ),
  Category(
    id: 'energia',
    slug: 'energia',
    name: 'Energía & Protección',
    description:
        'Sistemas de respaldo energético, UPS y protección para continuidad operativa.',
  ),
  Category(
    id: 'terminales',
    slug: 'terminales',
    name: 'Terminales POS & Móviles',
    description:
        'Terminales especializadas para almacén, punto de venta, RFID e industrial.',
  ),
  Category(
    id: 'consumibles',
    slug: 'consumibles',
    name: 'Consumibles & Accesorios',
    description:
        'Etiquetas, ribbon, tarjetas PVC, tóner y tinta para todas tus necesidades.',
  ),
  Category(
    id: 'escaneres',
    slug: 'escaneres',
    name: 'Escáneres de Códigos',
    description:
        'Escáneres 1D/2D para punto de venta, almacén e industria con máxima precisión.',
  ),
  Category(
    id: 'control-acceso',
    slug: 'control-acceso',
    name: 'Control de Acceso',
    description:
        'Barreras vehiculares, cerraduras, biométricos, torniquetes y lectoras para controlar quién entra.',
  ),
  Category(
    id: 'radiocomunicacion',
    slug: 'radiocomunicacion',
    name: 'Radiocomunicación',
    description:
        'Radios, antenas, torres, cables y accesorios para comunicaciones de largo alcance.',
  ),
  Category(
    id: 'cableado-estructurado',
    slug: 'cableado-estructurado',
    name: 'Cableado Estructurado',
    description:
        'Cableado de cobre y fibra óptica, racks, charolas y conectores para redes ordenadas.',
  ),
  Category(
    id: 'automatizacion-intrusion',
    slug: 'automatizacion-intrusion',
    name: 'Automatización & Intrusión',
    description:
        'Alarmas, detectores, cercas eléctricas y automatización de casas y edificios.',
  ),
  Category(
    id: 'deteccion-fuego',
    slug: 'deteccion-fuego',
    name: 'Detección de Fuego',
    description:
        'Paneles, detectores, sirenas y extinción para prevenir y detectar incendios.',
  ),
  Category(
    id: 'audio-video',
    slug: 'audio-video',
    name: 'Audio & Video Profesional',
    description:
        'Videowalls, pantallas, audio profesional y distribución de video para salas y comercios.',
  ),
  Category(
    id: 'gps-vehicular',
    slug: 'gps-vehicular',
    name: 'GPS & Equipamiento Vehicular',
    description:
        'Rastreo GPS, IoT y luces, barras y sirenas para vehículos de emergencia y de trabajo.',
  ),
  Category(
    id: 'herramientas',
    slug: 'herramientas',
    name: 'Herramientas & Material Eléctrico',
    description:
        'Canalización, herramienta, material eléctrico, medición y fijación para instalaciones.',
  ),
];

/// Busca el nombre visible de una categoria por id/slug (para headers, etc.).
String? categoryName(String? idOrSlug) {
  if (idOrSlug == null) return null;
  for (final c in productCategories) {
    if (c.id == idOrSlug || c.slug == idOrSlug) return c.name;
  }
  return idOrSlug;
}
