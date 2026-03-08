class FormatUtils {
  static String formatUnit(String? category, dynamic unitNum) {
    if (unitNum == null) return "-";
    
    String prefix = "V"; // Default
    if (category == "Cottages") {
      prefix = "C";
    } else if (category == "Lodging Deluxe") {
      prefix = "LD";
    } else if (category == "Dormitory") {
      prefix = "D";
    } else if (category?.startsWith("Banquet") ?? false) {
      prefix = "B";
    } else if (category == "Lawn") {
      prefix = "L";
    } else if (category == "Function Hall") {
      prefix = "F";
    } else if (category == "Meeting Hall") {
      prefix = "M";
    } else if (category == "Saptapadi Hall" || category == "Saptapadi") {
      prefix = "S";
    }

    return "$prefix-$unitNum";
  }
}
