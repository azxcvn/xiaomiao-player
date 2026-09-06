import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/cast_device.dart';
import 'package:moumou/services/cast/cast_service.dart';

void main() {
  test('isMediaRenderer：只认渲染器', () {
    expect(
      isMediaRenderer('urn:schemas-upnp-org:device:MediaRenderer:1'),
      isTrue,
    );
    expect(
      isMediaRenderer('urn:schemas-upnp-org:device:MediaServer:1'),
      isFalse,
    );
    expect(
      isMediaRenderer('urn:schemas-upnp-org:device:InternetGatewayDevice:1'),
      isFalse,
    );
    expect(isMediaRenderer(''), isFalse);
  });

  test('CastDevice.kind：取 deviceType 末段', () {
    const device = CastDevice(
      id: 'http://192.168.1.5:1234/desc.xml',
      friendlyName: '客厅电视',
      deviceType: 'urn:schemas-upnp-org:device:MediaRenderer:1',
    );
    expect(device.kind, 'MediaRenderer');
  });
}
