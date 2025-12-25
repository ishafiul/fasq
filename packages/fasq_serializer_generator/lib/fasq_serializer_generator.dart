library fasq_serializer_generator;

import 'package:build/build.dart';
import 'package:fasq_serializer_generator/src/generator/serializer_generator.dart';
import 'package:source_gen/source_gen.dart';

Builder serializerGenerator(BuilderOptions options) {
  return SharedPartBuilder(
    [const SerializerGenerator()],
    'serializers',
  );
}
