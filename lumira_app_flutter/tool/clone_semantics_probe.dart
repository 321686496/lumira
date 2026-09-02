import 'package:image/image.dart' as img;

void main() {
  final im = img.Image(width: 6, height: 6);
  im.setPixelRgb(0, 0, 10, 20, 30);
  im.setPixelRgb(1, 0, 200, 0, 0);

  final cl = im.clone();
  final beforeClone00 = cl.getPixel(0, 0);

  final blurred = img.gaussianBlur(im, radius: 2);
  final afterClone00 = cl.getPixel(0, 0); // clone受模糊影响?
  final orig00 = im.getPixel(0, 0); // im被模糊污染?
  final blr00 = blurred.getPixel(0, 0);
  final sameObj = identical(blurred, im); // gaussianBlur是否原地(同对象)

  print('clone(0,0) before blur=$beforeClone00  after blur=$afterClone00  (应同=clone未受影响)');
  print('gaussianBlur 同对象=$sameObj');
  print('im(0,0) after=${orig00.r},${orig00.g},${orig00.b}   blurred(0,0)=${blr00.r},${blr00.g},${blr00.b}');
  print('format=${im.format} cl=${cl.format} blr=${blurred.format}');
}