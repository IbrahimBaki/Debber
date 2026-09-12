export function userStatusLabel(status: string): string {
  switch (status) {
    case "active":
      return "فعال";
    case "needs_activation":
      return "محتاج تفعيل";
    case "disabled":
      return "موقوف";
    default:
      return status;
  }
}

export function invitationStatusLabel(status: string): string {
  switch (status) {
    case "pending":
      return "معلّقة";
    case "accepted":
      return "مقبولة";
    case "revoked":
      return "ملغاة";
    case "expired":
      return "منتهية";
    default:
      return status;
  }
}
