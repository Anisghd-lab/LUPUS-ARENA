class MortInstantaneeEvent {
  final String joueurId;
  final String nomJoueur;
  final String roleOriginal;
  final String causeMort;

  const MortInstantaneeEvent({
    required this.joueurId,
    required this.nomJoueur,
    required this.roleOriginal,
    required this.causeMort,
  });

  Map<String, dynamic> toMap() {
    return {
      'joueurId': joueurId,
      'nomJoueur': nomJoueur,
      'roleOriginal': roleOriginal,
      'causeMort': causeMort,
    };
  }

  factory MortInstantaneeEvent.fromMap(Map<dynamic, dynamic> map) {
    return MortInstantaneeEvent(
      joueurId: (map['joueurId'] ?? '').toString(),
      nomJoueur: (map['nomJoueur'] ?? '').toString(),
      roleOriginal: (map['roleOriginal'] ?? '').toString(),
      causeMort: (map['causeMort'] ?? '').toString(),
    );
  }
}
