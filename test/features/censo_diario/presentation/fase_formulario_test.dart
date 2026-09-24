import 'package:app_movil/features/censo_diario/presentation/state/fase_formulario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CA-04 — la voz nunca alcanza la persistencia', () {
    test(
      'ninguna fase de voz puede transicionar a guardando, exhaustivo',
      () {
        final fasesDeVoz =
            FaseFormulario.values.where((f) => f.esFaseDeVoz).toList();

        expect(
          fasesDeVoz,
          containsAll([
            FaseFormulario.escuchandoVoz,
            FaseFormulario.procesandoVoz,
            FaseFormulario.confirmandoVoz,
          ]),
          reason: 'si se agrega una fase de voz nueva, debe entrar acá',
        );

        for (final desde in fasesDeVoz) {
          expect(
            puedeTransicionar(desde, FaseFormulario.guardando),
            isFalse,
            reason: '${desde.name} no puede llegar a guardando',
          );
          expect(
            puedeTransicionar(desde, FaseFormulario.guardado),
            isFalse,
            reason: '${desde.name} no puede llegar a guardado',
          );
        }
      },
    );

    test('guardando solo es alcanzable desde edicion', () {
      final origenes = FaseFormulario.values
          .where((f) => puedeTransicionar(f, FaseFormulario.guardando))
          .toList();

      expect(origenes, [FaseFormulario.edicion]);
    });

    test('confirmandoVoz tiene una única salida, y es edicion', () {
      final salidas = transicionesPermitidas[FaseFormulario.confirmandoVoz]!;
      expect(salidas, {FaseFormulario.edicion});
    });

    test(
      'no hay camino de 2 saltos desde una fase de voz hasta guardando '
      'que no pase por edicion',
      () {
        for (final desde in FaseFormulario.values.where((f) => f.esFaseDeVoz)) {
          for (final intermedia in transicionesPermitidas[desde]!) {
            if (intermedia == FaseFormulario.edicion) continue;
            expect(
              puedeTransicionar(intermedia, FaseFormulario.guardando),
              isFalse,
              reason:
                  '${desde.name} → ${intermedia.name} → guardando saltea la '
                  'confirmación del usuario',
            );
          }
        }
      },
    );
  });

  group('Grafo de transiciones — integridad', () {
    test('toda fase declara su conjunto de salidas', () {
      for (final fase in FaseFormulario.values) {
        expect(
          transicionesPermitidas.containsKey(fase),
          isTrue,
          reason: 'falta declarar las salidas de ${fase.name}',
        );
      }
    });

    test('ninguna fase transiciona hacia sí misma', () {
      for (final fase in FaseFormulario.values) {
        expect(
          puedeTransicionar(fase, fase),
          isFalse,
          reason: '${fase.name} → ${fase.name}',
        );
      }
    });

    test('toda fase salvo inicial es alcanzable desde alguna otra', () {
      for (final destino in FaseFormulario.values) {
        if (destino == FaseFormulario.inicial) continue;
        final alcanzable = FaseFormulario.values
            .any((desde) => puedeTransicionar(desde, destino));
        expect(alcanzable, isTrue, reason: '${destino.name} es inalcanzable');
      }
    });

    test('inicial no es alcanzable: no se vuelve al arranque', () {
      for (final desde in FaseFormulario.values) {
        expect(puedeTransicionar(desde, FaseFormulario.inicial), isFalse);
      }
    });

    test('toda fase salvo guardado tiene al menos una salida', () {
      for (final fase in FaseFormulario.values) {
        expect(
          transicionesPermitidas[fase],
          isNotEmpty,
          reason: '${fase.name} es un callejón sin salida',
        );
      }
    });
  });

  group('Recorridos legales', () {
    void recorrer(List<FaseFormulario> camino) {
      for (var i = 0; i < camino.length - 1; i++) {
        expect(
          puedeTransicionar(camino[i], camino[i + 1]),
          isTrue,
          reason: '${camino[i].name} → ${camino[i + 1].name}',
        );
      }
    }

    test('camino feliz solo con teclado', () {
      recorrer([
        FaseFormulario.inicial,
        FaseFormulario.cargandoReferencias,
        FaseFormulario.edicion,
        FaseFormulario.guardando,
        FaseFormulario.guardado,
      ]);
    });

    test('camino con dictado aceptado', () {
      recorrer([
        FaseFormulario.edicion,
        FaseFormulario.escuchandoVoz,
        FaseFormulario.procesandoVoz,
        FaseFormulario.confirmandoVoz,
        FaseFormulario.edicion,
        FaseFormulario.guardando,
        FaseFormulario.guardado,
      ]);
    });

    test('camino con dictado descartado', () {
      recorrer([
        FaseFormulario.edicion,
        FaseFormulario.escuchandoVoz,
        FaseFormulario.procesandoVoz,
        FaseFormulario.confirmandoVoz,
        FaseFormulario.edicion,
      ]);
    });

    test('camino con dictado cancelado a mitad de la escucha', () {
      recorrer([
        FaseFormulario.edicion,
        FaseFormulario.escuchandoVoz,
        FaseFormulario.edicion,
      ]);
    });

    test('reintento tras un fallo de guardado conserva la edición', () {
      recorrer([
        FaseFormulario.edicion,
        FaseFormulario.guardando,
        FaseFormulario.error,
        FaseFormulario.edicion,
      ]);
    });

    test('cargar otro servicio tras guardar', () {
      recorrer([
        FaseFormulario.guardado,
        FaseFormulario.edicion,
      ]);
    });
  });
}
