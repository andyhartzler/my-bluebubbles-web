
import 'package:bluebubbles/features/mail/_tmail/core/core.dart';
import 'package:dartz/dartz.dart';

abstract class Validator<T> {
  Either<Failure, Success> validate(T value);
}