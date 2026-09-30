import '../../data/models/ive_intelligence.dart';
import '../../l10n/app_localizations.dart';

/// IVE-INTELLIGENCE-CORE-01 — one localized message per structured failure,
/// so the chat never shows raw exception text and never collapses every
/// failure into "something went wrong".
String iveFailureMessage(AppLocalizations l, IveFailure failure) => switch (failure) {
      IveFailure.authRequired => l.iveCoreSessionExpired,
      IveFailure.invalidRequest => l.iveCoreInvalidRequest,
      IveFailure.surfaceNotSupported => l.iveCoreSurfaceNotSupported,
      IveFailure.projectForbidden => l.iveCoreProjectForbidden,
      IveFailure.contextUnavailable => l.iveCoreContextUnavailable,
      IveFailure.modelUnavailable => l.iveCoreModelUnavailable,
      IveFailure.quotaExceeded => l.iveCoreQuotaExceeded,
      IveFailure.accessDenied => l.iveCoreAccessDenied,
      IveFailure.entitlementUnavailable => l.iveCoreContextUnavailable,
      IveFailure.unknown => l.iveCoreGenericError,
    };
