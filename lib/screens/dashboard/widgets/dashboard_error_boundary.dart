import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Error boundary widget that catches and logs rendering errors with detailed diagnostics
class DashboardErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? contextName;

  const DashboardErrorBoundary({
    super.key,
    required this.child,
    this.contextName,
  });

  @override
  State<DashboardErrorBoundary> createState() => _DashboardErrorBoundaryState();
}

class _DashboardErrorBoundaryState extends State<DashboardErrorBoundary> {
  FlutterExceptionHandler? _originalErrorHandler;
  bool _hasError = false;
  String? _errorMessage;
  String? _stackTrace;
  String? _errorLocation;

  @override
  void initState() {
    super.initState();
    _setupErrorHandler();
  }

  @override
  void dispose() {
    // Restore original error handler
    if (_originalErrorHandler != null) {
      FlutterError.onError = _originalErrorHandler;
    }
    super.dispose();
  }

  void _setupErrorHandler() {
    _originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log detailed error information
      _logDetailedError(details);

      // Call original handler if exists
      _originalErrorHandler?.call(details);

      // Update state if mounted
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = details.exceptionAsString();
          _stackTrace = details.stack?.toString();
          _errorLocation = _extractErrorLocation(details);
        });
      }
    };
  }

  void _logDetailedError(FlutterErrorDetails details) {
    final buffer = StringBuffer();
    buffer.writeln('');
    buffer.writeln('╔══════════════════════════════════════════════════════════════════════════════');
    buffer.writeln('║ DASHBOARD ERROR DIAGNOSTIC REPORT');
    buffer.writeln('║ Context: ${widget.contextName ?? 'Unknown'}');
    buffer.writeln('╠══════════════════════════════════════════════════════════════════════════════');
    buffer.writeln('║');
    buffer.writeln('║ ERROR TYPE: ${details.exception.runtimeType}');
    buffer.writeln('║ ERROR MESSAGE: ${details.exceptionAsString()}');
    buffer.writeln('║');
    buffer.writeln('║ LIBRARY: ${details.library ?? 'Unknown'}');
    buffer.writeln('║ CONTEXT: ${details.context?.toDescription() ?? 'No context'}');
    buffer.writeln('║');

    // Analyze the error for type casting issues
    final errorStr = details.exceptionAsString();
    if (errorStr.contains("type 'int' is not a subtype of type 'bool'")) {
      buffer.writeln('║ ⚠️  TYPE CASTING ERROR DETECTED');
      buffer.writeln('║');
      buffer.writeln('║ This error occurs when code tries to cast an integer to a boolean.');
      buffer.writeln('║ Common causes:');
      buffer.writeln('║   - Database returns 0/1 instead of true/false');
      buffer.writeln('║   - JSON parsing with incorrect type expectations');
      buffer.writeln('║   - Form field configuration with numeric default values');
      buffer.writeln('║');
    }

    buffer.writeln('║ STACK TRACE:');
    buffer.writeln('║');

    // Parse stack trace to find relevant frames
    if (details.stack != null) {
      final stackLines = details.stack.toString().split('\n');
      int relevantLineCount = 0;
      for (final line in stackLines) {
        if (relevantLineCount < 20) {
          // Highlight lines from our codebase
          if (line.contains('package:bluebubbles')) {
            buffer.writeln('║ >>> $line');
            relevantLineCount++;
          } else if (relevantLineCount < 10) {
            buffer.writeln('║     $line');
          }
        }
      }
    }

    buffer.writeln('║');
    buffer.writeln('║ DIAGNOSTIC SUGGESTIONS:');
    buffer.writeln('║');
    buffer.writeln('║ 1. Check the stack trace above for file:line references');
    buffer.writeln('║ 2. Look for "as bool?" casts in the referenced files');
    buffer.writeln('║ 3. Verify database column types match Dart expectations');
    buffer.writeln('║ 4. Check form field default values are correct type');
    buffer.writeln('║');
    buffer.writeln('╚══════════════════════════════════════════════════════════════════════════════');
    buffer.writeln('');

    debugPrint(buffer.toString());
  }

  String? _extractErrorLocation(FlutterErrorDetails details) {
    if (details.stack == null) return null;

    final stackLines = details.stack.toString().split('\n');
    for (final line in stackLines) {
      if (line.contains('package:bluebubbles')) {
        // Extract file:line information
        final match = RegExp(r'package:bluebubbles/(.+\.dart):(\d+)').firstMatch(line);
        if (match != null) {
          return '${match.group(1)}:${match.group(2)}';
        }
      }
    }
    return null;
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _stackTrace = null;
      _errorLocation = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorUI();
    }

    return widget.child;
  }

  Widget _buildErrorUI() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Rendering Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            if (widget.contextName != null)
              Text(
                'Context: ${widget.contextName}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _errorMessage ?? 'Unknown error',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.red[800],
                    ),
                  ),
                ],
              ),
            ),
            if (_errorLocation != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        'Location: $_errorLocation',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Check the browser console for full details',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The console contains a detailed diagnostic report including:\n'
                    '• Full stack trace with file locations\n'
                    '• Specific suggestions for fixing the issue\n'
                    '• Highlighted references to your code',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF32A6DE),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Utility class for safe type parsing with detailed error logging
class SafeParser {
  /// Safely parse a boolean value from JSON that might be an int or bool
  static bool parseBool(dynamic value, {bool defaultValue = false, String? fieldName, String? context}) {
    if (value == null) return defaultValue;

    if (value is bool) return value;

    if (value is int) {
      debugPrint('[SafeParser] Converting int to bool for ${fieldName ?? 'unknown field'} '
          '${context != null ? 'in $context' : ''}: $value -> ${value != 0}');
      return value != 0;
    }

    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }

    debugPrint('[SafeParser] WARNING: Could not parse bool from ${value.runtimeType} for '
        '${fieldName ?? 'unknown field'}: $value, using default: $defaultValue');
    return defaultValue;
  }

  /// Safely parse a nullable boolean value
  static bool? parseBoolNullable(dynamic value, {String? fieldName, String? context}) {
    if (value == null) return null;

    if (value is bool) return value;

    if (value is int) {
      debugPrint('[SafeParser] Converting int to bool? for ${fieldName ?? 'unknown field'} '
          '${context != null ? 'in $context' : ''}: $value -> ${value != 0}');
      return value != 0;
    }

    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }

    debugPrint('[SafeParser] WARNING: Could not parse bool? from ${value.runtimeType} for '
        '${fieldName ?? 'unknown field'}: $value');
    return null;
  }

  /// Wrap any operation in try-catch with detailed logging
  static T? safeExecute<T>(T Function() operation, {String? context, T? defaultValue}) {
    try {
      return operation();
    } catch (e, stackTrace) {
      final buffer = StringBuffer();
      buffer.writeln('[SafeParser] ERROR in ${context ?? 'unknown context'}');
      buffer.writeln('  Error: $e');
      buffer.writeln('  Stack: ${stackTrace.toString().split('\n').take(5).join('\n  ')}');
      debugPrint(buffer.toString());
      return defaultValue;
    }
  }
}
