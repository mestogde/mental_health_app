const List<String> materialImageAssets = [
  'assets/images/materials/material_1.png',
  'assets/images/materials/material_2.png',
  'assets/images/materials/material_3.png',
  'assets/images/materials/material_4.png',
  'assets/images/materials/material_5.png',
  'assets/images/materials/material_6.png',
];

const List<String> testImageAssets = [
  'assets/images/tests/test_1.png',
  'assets/images/tests/test_2.png',
  'assets/images/tests/test_3.png',
  'assets/images/tests/test_4.png',
  'assets/images/tests/test_5.png',
  'assets/images/tests/test_6.png',
  'assets/images/tests/test_7.png',
  'assets/images/tests/test_8.png',
  'assets/images/tests/test_9.png',
];

String assetByIndex(List<String> assets, int index) {
  return assets[index % assets.length];
}
