// lib/core/services/purchase_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart'; 

// The ID of your one-time purchase product in App Store Connect & Google Play Console.
const String _productID = 'full_access_pass'; // Use a simple ID

class PurchaseService with ChangeNotifier {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  late GameProvider _gameProvider; // To grant entitlement

  // Service State
  bool isAvailable = false;
  bool purchasePending = false;
  String? errorMessage;
  ProductDetails? product;

  /// Call this once when the app starts.
  void init(GameProvider gameProvider) {
    _gameProvider = gameProvider;
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdates(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // Handle stream errors
      errorMessage = "Purchase stream error: $error";
      notifyListeners();
    });
    _checkStoreAvailability();
  }

  void dispose() {
    // On iOS, it's important to remove the transaction observer.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      iosPlatformAddition.setDelegate(null);
    }
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _checkStoreAvailability() async {
    isAvailable = await _inAppPurchase.isAvailable();
    if (isAvailable) {
      await loadProducts();
    } else {
      errorMessage = "The store is unavailable.";
    }
    notifyListeners();
  }

  /// Fetches product details from the store.
  Future<void> loadProducts() async {
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({_productID});
    if (response.notFoundIDs.isNotEmpty) {
      errorMessage = "Product '$_productID' not found in the store.";
    }
    if (response.productDetails.isNotEmpty) {
      product = response.productDetails.first;
      errorMessage = null; // Clear previous errors if products load
    }
    notifyListeners();
  }

  /// Initiates the purchase flow for the product.
  Future<void> buyProduct() async {
    if (product == null) {
      errorMessage = "Product not loaded yet. Cannot initiate purchase.";
      notifyListeners();
      return;
    }
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product!);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Restores previous purchases (primarily for iOS).
  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  void _listenToPurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          purchasePending = true;
          errorMessage = null;
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _handleSuccessfulPurchase(purchaseDetails);
          break;
        case PurchaseStatus.error:
          purchasePending = false;
          errorMessage = purchaseDetails.error?.message ?? "An unknown error occurred.";
          notifyListeners();
          _inAppPurchase.completePurchase(purchaseDetails);
          break;
        case PurchaseStatus.canceled:
          purchasePending = false;
          notifyListeners();
          _inAppPurchase.completePurchase(purchaseDetails);
          break;
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.productID == _productID) {
      // 1. Grant entitlement to the user
      _gameProvider.unlockFullVersion();

      // 2. Acknowledge the purchase with the store
      // `completePurchase` is crucial to prevent the purchase from being repeatedly delivered.
      await _inAppPurchase.completePurchase(purchaseDetails);
    }
    purchasePending = false;
    errorMessage = null;
    notifyListeners();
  }
}