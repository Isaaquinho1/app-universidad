class InstitutionalCareer {
  const InstitutionalCareer({required this.id, required this.name});

  final String id;
  final String name;
}

abstract final class InstitutionalCareers {
  static const itic = InstitutionalCareer(
    id: 'itic-2010-225',
    name: 'Ingeniería en Tecnologías de la Información y Comunicaciones',
  );

  static const igem = InstitutionalCareer(
    id: 'igem-2009-201',
    name: 'Ingeniería en Gestión Empresarial',
  );

  static const ielc = InstitutionalCareer(
    id: 'ielc-2010-211',
    name: 'Ingeniería Electrónica',
  );

  static const values = <InstitutionalCareer>[itic, igem, ielc];

  static String labelFor(String id) {
    for (final career in values) {
      if (career.id == id) {
        return career.name;
      }
    }

    return id;
  }
}
