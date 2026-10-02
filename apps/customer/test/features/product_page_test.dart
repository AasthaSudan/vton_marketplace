import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_shop/features/address/data/repositories/mock_address_repository.dart';
import 'package:clothsy_shop/features/catalog/data/repositories/mock_catalog_repository.dart';
import 'package:clothsy_shop/features/catalog/presentation/widgets/size_chart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Size chart', () {
    final catalog = MockCatalogRepository();

    Future<Product> product(String id) async =>
        (await catalog.getProductById(id))!;

    test('clothing gets body measurements', () async {
      final chart = SizeChart.forProduct(await product('p_lavender_blazer'));
      expect(chart?.columns, contains('Bust'));
    });

    test('heels get UK / EU sizes', () async {
      final chart = SizeChart.forProduct(await product('p6'));
      expect(chart?.columns.first, 'UK');
    });

    test('bags have no size chart', () async {
      expect(SizeChart.forProduct(await product('p5')), isNull);
    });
  });

  group('PIN serviceability', () {
    final repo = MockAddressRepository();

    test('known launch PINs ship faster and offer COD', () async {
      final delhi = await repo.checkPinServiceability('110001');
      expect(delhi.serviceable, isTrue);
      expect(delhi.codAvailable, isTrue);
      expect(delhi.etaDays, 2);
      expect(delhi.city, 'New Delhi');
    });

    test('some PINs are prepaid only', () async {
      final kolkata = await repo.checkPinServiceability('700001');
      expect(kolkata.serviceable, isTrue);
      expect(kolkata.codAvailable, isFalse);
    });

    test('invalid PINs are not serviceable', () async {
      expect(
        (await repo.checkPinServiceability('012345')).serviceable,
        isFalse,
      );
      expect((await repo.checkPinServiceability('1234')).serviceable, isFalse);
    });
  });
}
