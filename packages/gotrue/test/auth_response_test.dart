// ignore_for_file: constant_identifier_names

import 'package:gotrue/src/types/auth_response.dart';
import 'package:test/test.dart';

enum TestEnum {
  camelCase,
  PascalCase,
  UPPERCASE,
  lowercase,
  snake_case,
  UPPER_SNAKE_CASE,
  camel_Snake_Case,
}

void main() {
  group('ToSnakeCase extension', () {
    test('should convert camelCase to snake_case', () {
      expect(TestEnum.camelCase.snakeCase, 'camel_case');
    });

    test('should convert PascalCase to snake_case', () {
      expect(TestEnum.PascalCase.snakeCase, 'pascal_case');
    });

    test('should convert UPPERCASE to snake_case', () {
      expect(TestEnum.UPPERCASE.snakeCase, 'uppercase');
    });

    test('should convert lowercase to snake_case', () {
      expect(TestEnum.lowercase.snakeCase, 'lowercase');
    });

    test('should convert snake_case to snake_case', () {
      expect(TestEnum.snake_case.snakeCase, 'snake_case');
    });

    test('should convert UPPER_SNAKE_CASE to snake_case', () {
      expect(TestEnum.UPPER_SNAKE_CASE.snakeCase, 'upper_snake_case');
    });

    test('should convert camel_Snake_Case to snake_case', () {
      expect(TestEnum.camel_Snake_Case.snakeCase, 'camel_snake_case');
    });
  });
}
