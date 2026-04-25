import 'package:bluebubbles/features/mail/_tmail/core/domain/exceptions/app_base_exception.dart';

abstract class CacheException extends AppBaseException {
  const CacheException([super.message]);
}

class UnknownCacheError extends CacheException {
  const UnknownCacheError([super.message]);

  @override
  String get exceptionName => 'UnknownCacheError';
}
