import 'package:clothsy_shop/features/catalog/domain/entities/product.dart';
import 'tryon_photo.dart';

enum TryOnJobStatus {
  idle,
  validatingPhoto,
  submitting,
  processing,
  completed,
  failed,
}

class ProcessingStep {
  final String title;
  final String description;
  final double progress; // 0.0 to 1.0

  const ProcessingStep({
    required this.title,
    required this.description,
    required this.progress,
  });
}

class TryOnResult {
  final String id;
  final TryOnPhoto photo;
  final Product product;
  final ProductVariant variant;
  final String resultImageUrl;
  final DateTime createdAt;
  final int? rating;
  final String? feedbackNote;

  const TryOnResult({
    required this.id,
    required this.photo,
    required this.product,
    required this.variant,
    required this.resultImageUrl,
    required this.createdAt,
    this.rating,
    this.feedbackNote,
  });

  String get cacheKey => '${photo.id}_${product.id}_${variant.id}';

  TryOnResult copyWith({
    String? id,
    TryOnPhoto? photo,
    Product? product,
    ProductVariant? variant,
    String? resultImageUrl,
    DateTime? createdAt,
    int? rating,
    String? feedbackNote,
  }) {
    return TryOnResult(
      id: id ?? this.id,
      photo: photo ?? this.photo,
      product: product ?? this.product,
      variant: variant ?? this.variant,
      resultImageUrl: resultImageUrl ?? this.resultImageUrl,
      createdAt: createdAt ?? this.createdAt,
      rating: rating ?? this.rating,
      feedbackNote: feedbackNote ?? this.feedbackNote,
    );
  }
}

class TryOnSessionState {
  final TryOnPhoto? selectedPhoto;
  final Product? selectedProduct;
  final ProductVariant? selectedVariant;
  final TryOnJobStatus status;
  final ProcessingStep? currentStep;
  final TryOnResult? currentResult;
  final String? errorMessage;
  final int remainingCredits;
  final bool hasConsented;

  const TryOnSessionState({
    this.selectedPhoto,
    this.selectedProduct,
    this.selectedVariant,
    this.status = TryOnJobStatus.idle,
    this.currentStep,
    this.currentResult,
    this.errorMessage,
    this.remainingCredits = 10,
    this.hasConsented = false,
  });

  bool get isProcessing =>
      status == TryOnJobStatus.validatingPhoto ||
      status == TryOnJobStatus.submitting ||
      status == TryOnJobStatus.processing;

  bool get canGenerate =>
      selectedPhoto != null &&
      selectedProduct != null &&
      selectedVariant != null &&
      !isProcessing;

  TryOnSessionState copyWith({
    TryOnPhoto? selectedPhoto,
    Product? selectedProduct,
    ProductVariant? selectedVariant,
    TryOnJobStatus? status,
    ProcessingStep? currentStep,
    TryOnResult? currentResult,
    String? errorMessage,
    int? remainingCredits,
    bool? hasConsented,
    bool clearCurrentResult = false,
    bool clearError = false,
  }) {
    return TryOnSessionState(
      selectedPhoto: selectedPhoto ?? this.selectedPhoto,
      selectedProduct: selectedProduct ?? this.selectedProduct,
      selectedVariant: selectedVariant ?? this.selectedVariant,
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      currentResult: clearCurrentResult ? null : (currentResult ?? this.currentResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      remainingCredits: remainingCredits ?? this.remainingCredits,
      hasConsented: hasConsented ?? this.hasConsented,
    );
  }
}
