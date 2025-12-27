import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, [this.code]);

  @override
  List<Object?> get props => [message, code];
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, [super.code]);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, [super.code]);
}

class MacroExecutionFailure extends Failure {
  const MacroExecutionFailure(super.message, [super.code]);
}

class PenaltyExecutionFailure extends Failure {
  const PenaltyExecutionFailure(super.message, [super.code]);
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message, [super.code]);
}

class PlatformChannelFailure extends Failure {
  const PlatformChannelFailure(super.message, [super.code]);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, [super.code]);
}
