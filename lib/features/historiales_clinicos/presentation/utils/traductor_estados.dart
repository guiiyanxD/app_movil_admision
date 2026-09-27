class TraductorEstados {
  static String traducir(String estado) {
    switch (estado) {
      case 'PENDING':
      case 'REQUESTED':
        return 'Pendiente';
      case 'READY':
        return 'Listo';
      case 'LENT':
        return 'Prestado';
      case 'NOT_FOUND':
        return 'No encontrado';
      case 'NOTIFIED':
        return 'Notificado';
      case 'RECEIVED':
        return 'Recibido';
      case 'DISCREPANCY':
        return 'Discrepancia';
      case 'CANCELED_DUE_TO_EGRESO':
        return 'Cancelado por Alta';
      default:
        return estado;
    }
  }
}
