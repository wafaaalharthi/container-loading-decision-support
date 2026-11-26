import 'shipment.dart';

/// SH-102 demo shipment (same data as the prototype and the engine case).
const List<BoxGroup> sh102Groups = [
  BoxGroup(code: 'B01', kind: 'electronics', contents: 'Electronic devices', lengthMm: 800, widthMm: 600, heightMm: 550, weightKg: 24, quantity: 24, priority: 1, orientation: 'upright', fragile: true, stackable: false),
  BoxGroup(code: 'B02', kind: 'machinery', contents: 'Equipment', lengthMm: 1000, widthMm: 750, heightMm: 800, weightKg: 95, quantity: 24, priority: 3, orientation: 'upright'),
  BoxGroup(code: 'B03', kind: 'other', contents: 'Supplies', lengthMm: 600, widthMm: 500, heightMm: 600, weightKg: 30, quantity: 50, priority: 2),
  BoxGroup(code: 'B04', kind: 'machinery', contents: 'Machine part', lengthMm: 1500, widthMm: 1100, heightMm: 900, weightKg: 650, quantity: 2, priority: 3, orientation: 'upright', floorOnly: true, stackable: false),
  BoxGroup(code: 'B05', kind: 'iron_metal', contents: 'Pipe crate', lengthMm: 6400, widthMm: 600, heightMm: 600, weightKg: 180, quantity: 1, priority: 2),
  BoxGroup(code: 'B06', kind: 'paper', contents: 'Documents', lengthMm: 400, widthMm: 300, heightMm: 300, weightKg: 8, quantity: 20, priority: 1),
];
