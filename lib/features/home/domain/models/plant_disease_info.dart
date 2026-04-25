class PlantDiseaseInfo {
  final String disease;
  final String status;
  final String suggestion;
  final bool isHealthy;

  PlantDiseaseInfo({
    required this.disease,
    required this.status,
    required this.suggestion,
    required this.isHealthy,
  });

  factory PlantDiseaseInfo.fromLabel(String label) {
    // Clean up the label: replace ___ with ' - ' and _ with space
    String cleanName = label.replaceAll('___', ' - ').replaceAll('_', ' ');
    bool healthy = cleanName.toLowerCase().contains('healthy');

    String status = healthy ? "Healthy ✅" : "Infected ❌";
    
    // Simple logic for suggestions
    String suggestion = healthy 
        ? "Your plant looks great! Keep up the good work." 
        : _getSuggestionForDisease(cleanName);

    return PlantDiseaseInfo(
      disease: cleanName,
      status: status,
      suggestion: suggestion,
      isHealthy: healthy,
    );
  }

  static String _getSuggestionForDisease(String name) {
    name = name.toLowerCase();
    if (name.contains('scab')) {
      return "Use fungicide and prune infected branches to improve air circulation.";
    } else if (name.contains('rot')) {
      return "Remove affected fruit/leaves and apply a copper-based fungicide.";
    } else if (name.contains('rust')) {
      return "Destroy infected debris and use rust-resistant varieties.";
    } else if (name.contains('mildew')) {
      return "Increase air flow and apply sulfur-based sprays early in the morning.";
    } else if (name.contains('blight')) {
      return "Use fungicide, remove infected leaves, and avoid overhead watering.";
    } else if (name.contains('spot')) {
      return "Remove spotted leaves and apply neem oil or fungicide.";
    } else if (name.contains('measles') || name.contains('esca')) {
      return "Prune dead wood and avoid large pruning wounds in wet weather.";
    } else if (name.contains('greening')) {
      return "Control psyllids (insects) and remove severely infected trees.";
    }
    return "Consult a local agricultural specialist for the best treatment.";
  }
}
