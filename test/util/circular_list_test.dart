import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/util/circular_list.dart';

void main() {
  group("CircularList Tests", () {
    test("normal creation test", () {
      final cl = CircularList<int>(1000);

      expect(cl, isNotNull);
      expect(cl.maxLength, 1000);
    });

    test("change max value", () {
      final cl = CircularList<int>(2000);
      expect(cl.maxLength, 2000);
      cl.maxLength = 3000;
      expect(cl.maxLength, 3000);
    });

    test("circle works", () {
      final cl = CircularList<int>(10);
      expect(cl.maxLength, 10);
      cl.pushAll(List<int>.generate(10, (index) => index));

      expect(cl.length, 10);
      expect(cl[0], 0);
      expect(cl[9], 9);

      cl.push(10);

      expect(cl.length, 10);
      expect(cl[0], 1);
      expect(cl[9], 10);
    });

    test("change max value after circle", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(15, (index) => index));

      expect(cl.length, 10);
      expect(cl[0], 5);
      expect(cl[9], 14);

      cl.maxLength = 20;

      expect(cl.length, 10);
      expect(cl[0], 5);
      expect(cl[9], 14);

      cl.pushAll(List<int>.generate(5, (index) => 15 + index));

      expect(cl[0], 5);
      expect(cl[9], 14);
      expect(cl[14], 19);
    });

    test("setting the length erases trail", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(10, (index) => index));

      expect(cl.length, 10);
      expect(cl[0], 0);
      expect(cl[9], 9);

      cl.length = 5;

      expect(cl.length, 5);
      expect(cl[0], 0);
      expect(() => cl[5], throwsRangeError);
    });

    test("foreach works", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(10, (index) => index));

      final collectedItems = List<int>.empty(growable: true);

      cl.forEach((item) {
        collectedItems.add(item);
      });

      expect(collectedItems.length, 10);
      expect(collectedItems[0], 0);
      expect(collectedItems[9], 9);
    });

    test("index operator set works", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(10, (index) => index));

      expect(cl.length, 10);
      expect(cl[5], 5);

      cl[5] = 50;

      expect(cl[5], 50);
    });

    test("clear works", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(10, (index) => index));
      expect(cl[5], 5);

      cl.clear();

      expect(cl.length, 0);
      expect(() => cl[5], throwsRangeError);
    });

    test("pop works", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(10, (index) => index));
      expect(cl.length, 10);
      expect(cl[9], 9);

      final val = cl.pop();

      expect(val, 9);
      expect(cl.length, 9);
      expect(() => cl[9], throwsRangeError);
      expect(cl[8], 8);
    });

    test("pop on empty throws", () {
      final cl = CircularList<int>(10);
      expect(() => cl.pop(), throwsA(anything));
    });

    test("remove one works", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(10, (index) => index));
      expect(cl.length, 10);
      expect(cl[5], 5);

      cl.remove(5);

      expect(cl.length, 9);
      expect(cl[5], 6);
    });

    test("remove multiple works", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(10, (index) => index));
      expect(cl.length, 10);
      expect(cl[5], 5);

      cl.remove(5, 3);

      expect(cl.length, 7);
      expect(cl[5], 8);
    });

    test("remove circle works", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(15, (index) => index));
      expect(cl.length, 10);
      expect(cl[0], 5);

      cl.remove(0, 9);

      expect(cl.length, 1);
      expect(cl[0], 14);
    });

    test("remove too much works", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(10, (index) => index));
      expect(cl.length, 10);
      expect(cl[5], 5);

      cl.remove(5, 10);

      expect(cl.length, 5);
      expect(cl[0], 0);
    });

    test("insert works", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(5, (index) => index));
      expect(cl.length, 5);
      expect(cl[0], 0);
      cl.insert(0, 100);

      expect(cl.length, 6);
      expect(cl[0], 100);
      expect(cl[1], 0);
    });

    test("insert circular works", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(10, (index) => index));
      expect(cl.length, 10);
      expect(cl[0], 0);
      expect(cl[1], 1);
      expect(cl[9], 9);

      cl.insert(1, 100);

      expect(cl.length, 10);
      expect(cl[0], 100); //circle leads to 100 moving one index down
      expect(cl[1], 1);
    });

    test("insert circular immediately remove works", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(10, (index) => index));
      expect(cl.length, 10);
      expect(cl[0], 0);
      expect(cl[1], 1);
      expect(cl[9], 9);

      cl.insert(0, 100);

      expect(cl.length, 10);
      expect(cl[0], 0); //the inserted 100 fell over immediately
      expect(cl[1], 1);
    });

    test("insert all works", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(10, (index) => index));
      expect(cl.length, 10);
      expect(cl[0], 0);
      expect(cl[1], 1);
      expect(cl[9], 9);

      cl.insertAll(2, List<int>.generate(2, (index) => 20 + index));

      expect(cl.length, 10);
      expect(cl[0], 20);
      expect(cl[1], 21);
      expect(cl[3], 3);
      expect(cl[9], 9);
    });

    test("trim start works", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(10, (index) => index));
      expect(cl.length, 10);
      expect(cl[0], 0);
      expect(cl[1], 1);
      expect(cl[9], 9);

      cl.trimStart(5);

      expect(cl.length, 5);
      expect(cl[0], 5);
      expect(cl[1], 6);
      expect(cl[4], 9);
    });

    test("trim start with more than length works", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(10, (index) => index));
      expect(cl.length, 10);
      expect(cl[0], 0);
      expect(cl[1], 1);
      expect(cl[9], 9);

      cl.trimStart(15);

      expect(cl.length, 0);
    });

    test("shift elements works", () {
      final cl = CircularList<int>(20);
      cl.pushAll(List<int>.generate(20, (index) => index));
      expect(cl.length, 20);
      expect(cl[0], 0);
      expect(cl[1], 1);
      expect(cl[9], 9);

      cl.shiftElements(5, 3, 2);

      expect(cl.length, 20);
      expect(cl[0], 0); // untouched
      expect(cl[1], 1); // untouched
      expect(cl[5], 5); // moved
      expect(cl[6], 6); // moved
      expect(cl[7], 5); // moved (7) and target (5)
      expect(cl[8], 6); // target (6)
      expect(cl[9], 7); // target (7)
      expect(cl[10], 10); // untouched
      expect(cl[11], 11); // untouched
    });

    test("shift elements over bounds throws", () {
      final cl = CircularList<int>(10);
      cl.pushAll(List<int>.generate(10, (index) => index));
      expect(cl.length, 10);
      expect(cl[0], 0);
      expect(cl[1], 1);
      expect(cl[9], 9);

      expect(() => cl.shiftElements(8, 2, 3), throwsA(anything));
      expect(() => cl.shiftElements(2, 3, -3), throwsA(anything));
    });
  });
}
