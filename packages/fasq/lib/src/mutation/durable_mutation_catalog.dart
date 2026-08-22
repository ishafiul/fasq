import 'package:fasq/src/mutation/durable_mutation_definition.dart';
import 'package:fasq/src/mutation/mutation_contract.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';

/// Runtime catalog of durable mutation contracts registered at bootstrap.
///
/// Widgets resolve contracts with a [FasqMutationKey], preserving result and
/// variable types without receiving executor objects through feature scopes.
final class DurableMutationCatalog {
  /// Creates a catalog and rejects ambiguous duplicate runtime keys.
  DurableMutationCatalog(
    Iterable<DurableMutationDefinitionBase> definitions,
  ) : _definitions = _index(definitions);

  final Map<MutationKey, DurableMutationDefinitionBase> _definitions;

  /// Resolves the exact typed definition represented by [key].
  DurableMutationDefinition<TData, TVariables> resolve<TData, TVariables>(
    FasqMutationKey<TData, TVariables> key,
  ) {
    final definition = _definitions[key.runtimeKey];
    if (definition == null) {
      throw UnknownMutationKeyException(key.value);
    }
    if (definition is! DurableMutationDefinition<TData, TVariables>) {
      throw MutationRegistrationTypeException(
        key: key.value,
        expectedDataType: '$TData',
        expectedVariablesType: '$TVariables',
      );
    }
    return definition;
  }

  /// Whether [key] was registered during runtime bootstrap.
  bool contains<TData, TVariables>(
    FasqMutationKey<TData, TVariables> key,
  ) => _definitions.containsKey(key.runtimeKey);

  static Map<MutationKey, DurableMutationDefinitionBase> _index(
    Iterable<DurableMutationDefinitionBase> definitions,
  ) {
    final indexed = <MutationKey, DurableMutationDefinitionBase>{};
    for (final definition in definitions) {
      final previous = indexed[definition.key];
      if (previous != null) {
        throw DuplicateMutationRegistrationException(definition.key.key);
      }
      indexed[definition.key] = definition;
    }
    return Map.unmodifiable(indexed);
  }
}
