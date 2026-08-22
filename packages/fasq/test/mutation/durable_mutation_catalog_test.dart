import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const key = FasqMutationKey<String, int>(
    namespace: 'catalog',
    name: 'typed',
  );

  DurableMutation<String, int> definition() {
    return DurableMutation<String, int>.define(
      key: key,
      codec: const JsonMutationCodec<int>(
        encoder: _encodeInt,
        decoder: _decodeInt,
      ),
      execute: (value) async => '$value',
    );
  }

  test('resolves a bootstrapped definition through its typed key', () {
    final mutation = definition();
    final catalog = DurableMutationCatalog([mutation]);

    expect(catalog.resolve(key), same(mutation));
  });

  test('rejects a key with matching storage identity but wrong types', () {
    final catalog = DurableMutationCatalog([definition()]);
    const wrongTypes = FasqMutationKey<bool, double>(
      namespace: 'catalog',
      name: 'typed',
    );

    expect(
      () => catalog.resolve(wrongTypes),
      throwsA(isA<MutationRegistrationTypeException>()),
    );
  });

  test('rejects duplicate runtime keys during bootstrap', () {
    expect(
      () => DurableMutationCatalog([definition(), definition()]),
      throwsA(isA<DuplicateMutationRegistrationException>()),
    );
  });
}

Object? _encodeInt(int value) => value;

int _decodeInt(Object? value) => value! as int;
