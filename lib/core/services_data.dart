class ResortPackage {
  final String name;
  final double price;
  final String description;
  final List<String> inclusions;

  const ResortPackage({
    required this.name,
    required this.price,
    required this.description,
    required this.inclusions,
  });
}

class ResortServicesData {
  static const List<ResortPackage> packages = [
    ResortPackage(
      name: "One Day Stay Package",
      price: 1500.0, // Example price, can be adjusted
      description: "Complete 24 Hours stay experience with all meals and amenities.",
      inclusions: [
        "Cottage / Room accommodation",
        "Welcome drink",
        "Breakfast",
        "Lunch",
        "Evening tea/snacks",
        "Swimming pool access",
        "Indoor games",
        "Parking",
      ],
    ),
    ResortPackage(
      name: "Pre-Wedding Shoot Package",
      price: 5000.0,
      description: "Perfect for capturing your special moments in scenic locations.",
      inclusions: [
        "Garden / scenic location access",
        "Dressing room / cottage",
        "Decorative setup",
        "Electricity & lighting access",
      ],
    ),
    ResortPackage(
      name: "Party Hub / Birthday Party",
      price: 10000.0,
      description: "Host your vibrant celebrations with complete setup.",
      inclusions: [
        "Party hall or lawn access",
        "Decoration setup",
        "DJ / music system",
        "Lighting",
        "Catering support",
      ],
    ),
    ResortPackage(
      name: "Corporate Event / Meeting",
      price: 8000.0,
      description: "Professional setting for meetings and corporate gatherings.",
      inclusions: [
        "Conference hall",
        "Projector / presentation screen",
        "WiFi",
        "Tea / coffee service",
        "Lunch / snacks option",
      ],
    ),
    ResortPackage(
      name: "Picnic / Day Out Package",
      price: 800.0,
      description: "Fun-filled day outing for families and friends.",
      inclusions: [
        "Resort entry",
        "Swimming pool access",
        "Garden / outdoor activities",
        "Lunch buffet",
        "Indoor and outdoor games",
      ],
    ),
  ];
}
