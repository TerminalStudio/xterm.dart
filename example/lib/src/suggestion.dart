class SuggestionEngine {
  final _specs = <String, FigSubCommand>{};

  void load(Map<String, dynamic> specs) {
    for (var spec in specs.entries) {
      addSpec(spec.key, FigSubCommand.fromJson(spec.value));
    }
  }

  void addSpec(String name, FigSubCommand spec) {
    _specs[name] = spec;
  }

  Iterable<FigSuggestion> getSuggestions(String command) {
    final args = command.split(' ').where((e) => e.isNotEmpty).toList();

    if (args.isEmpty) {
      return [];
    }

    return _getSuggestions(args, _specs);
  }

  Iterable<FigSuggestion> _getSuggestions(
    List<String> input,
    Map<String, FigSubCommand> specs,
  ) sync* {
    assert(input.isNotEmpty);

    // The subcommand scope we are currently in.
    FigSubCommand? currentCommand;

    // The last suggestion we recongnized. This is used to determine what to
    // suggest next. Valid values are:
    // - null: We are at the root of the command.
    // - currentCommand
    // - option of currentCommand
    FigSuggestion? last;

    for (final part in input) {
      if (currentCommand == null) {
        currentCommand = specs[part];
        if (currentCommand == null) {
          if (part.length >= 4) {
            yield* specs.values.matchPrefix(input.last);
          }
          return;
        }
        last = currentCommand;
        continue;
      }

      final option = currentCommand.options.match(part);
      if (option != null) {
        last = option;
        continue;
      }

      final subCommand = currentCommand.subCommands.match(part);
      if (subCommand != null) {
        currentCommand = subCommand;
        last = currentCommand;
        continue;
      }

      last = null;
    }

    if (currentCommand == null) {
      return;
    }

    if (last is FigSubCommand) {
      yield* last.args;
      yield* last.subCommands;
      yield* last.options;
    } else if (last is FigOption) {
      if (last.args.isEmpty) {
        yield* currentCommand.args;
        yield* currentCommand.options;
      } else {
        yield* last.args;
      }
    } else {
      yield* currentCommand.subCommands.matchPrefix(input.last);
      yield* currentCommand.options.matchPrefix(input.last);
      yield* currentCommand.args;
    }
  }
}

extension on Iterable<FigSubCommand> {
  FigSubCommand? match(String name) {
    for (final command in this) {
      if (command.names.contains(name)) {
        return command;
      }
    }
    return null;
  }

  Iterable<FigSubCommand> matchPrefix(String name) sync* {
    for (final command in this) {
      if (command.names.any((e) => e.startsWith(name))) {
        yield command;
      }
    }
  }
}

extension on Iterable<FigOption> {
  FigOption? match(String name) {
    for (final option in this) {
      if (option.name.contains(name)) {
        return option;
      }
    }
    return null;
  }

  Iterable<FigOption> matchPrefix(String name) sync* {
    for (final option in this) {
      if (option.name.any((e) => e.startsWith(name))) {
        yield option;
      }
    }
  }
}

sealed class FigSuggestion {
  final String? description;

  FigSuggestion({this.description});
}

class FigSubCommand extends FigSuggestion {
  final List<String> names;

  final List<FigSubCommand> subCommands;

  final bool requiresSubCommand;

  final List<FigOption> options;

  final List<FigArgument> args;

  FigSubCommand({
    required this.names,
    super.description,
    required this.subCommands,
    required this.requiresSubCommand,
    required this.options,
    required this.args,
  });

  factory FigSubCommand.fromJson(Map<String, dynamic> json) {
    return FigSubCommand(
      names: singleOrList<String>(json['name']),
      description: json['description'],
      subCommands: singleOrList(json['subcommands'])
          .map<FigSubCommand>((e) => FigSubCommand.fromJson(e))
          .toList(),
      requiresSubCommand: json['requiresSubCommand'] ?? false,
      options: singleOrList(json['options'])
          .map<FigOption>((e) => FigOption.fromJson(e))
          .toList(),
      args: singleOrList(json['args'])
          .map<FigArgument>((e) => FigArgument.fromJson(e))
          .toList(),
    );
  }

  @override
  String toString() {
    return 'FigSubCommand($names)';
  }
}

class FigOption extends FigSuggestion {
  final List<String> name;

  final List<FigArgument> args;

  final bool isPersistent;

  final bool isRequired;

  final String? separator;

  final int? repeat;

  final List<String> exclusiveOn;

  final List<String> dependsOn;

  FigOption({
    required this.name,
    super.description,
    required this.args,
    required this.isPersistent,
    required this.isRequired,
    this.separator,
    this.repeat,
    required this.exclusiveOn,
    required this.dependsOn,
  });

  factory FigOption.fromJson(Map<String, dynamic> json) {
    return FigOption(
      name: singleOrList(json['name']).cast<String>(),
      description: json['description'],
      args: singleOrList(json['args'])
          .map<FigArgument>((e) => FigArgument.fromJson(e))
          .toList(),
      isPersistent: json['isPersistent'] ?? false,
      isRequired: json['isRequired'] ?? false,
      separator: json['separator'],
      repeat: json['repeat'],
      exclusiveOn: singleOrList<String>(json['exclusiveOn']),
      dependsOn: singleOrList<String>(json['dependsOn']),
    );
  }

  @override
  String toString() {
    return 'FigOption($name)';
  }
}

class FigArgument extends FigSuggestion {
  final String? name;

  final bool isDangerous;

  final bool isOptional;

  final bool isCommand;

  final String? defaultValue;

  FigArgument({
    required this.name,
    super.description,
    required this.isDangerous,
    required this.isOptional,
    required this.isCommand,
    this.defaultValue,
  });

  factory FigArgument.fromJson(Map<String, dynamic> json) {
    return FigArgument(
      name: json['name'],
      description: json['description'],
      isDangerous: json['isDangerous'] ?? false,
      isOptional: json['isOptional'] ?? false,
      isCommand: json['isCommand'] ?? false,
      defaultValue: json['defaultValue'],
    );
  }

  @override
  String toString() {
    return 'FigArgument($name)';
  }
}

List<T> singleOrList<T>(item) {
  if (item == null) return <T>[];
  return item is List ? item.cast<T>() : <T>[item as T];
}
