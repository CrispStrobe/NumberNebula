import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One match per dialog surface. Dialog subclasses are real dialogs; a nested
/// styling wrapper is not a second modal. Separate routes still count twice.
Finder get roundDialogs => find.byElementPredicate((element) {
      if (element.widget is! Dialog) {
        return false;
      }
      var nested = false;
      element.visitAncestorElements((ancestor) {
        if (ancestor.widget is Dialog) {
          nested = true;
          return false;
        }
        return true;
      });
      return !nested;
    }, description: 'outermost Dialog surfaces, including subclasses');
