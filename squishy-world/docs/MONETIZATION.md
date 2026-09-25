# MONETIZACIÓN — Robux en Squishy World

Todo el código ya está: `Config/Monetization.luau` (catálogo), `server/Services/MonetizationService.luau`
(entrega segura) y la pestaña **⭐ Robux** de la Tienda (`client/Controllers/Shop.luau`).
Lo único que falta es **crear los ítems en Roblox y pegar sus ids**.

## Catálogo actual

### Game Passes (se compran una vez, son para siempre)
| key | Nombre | Efecto (lo aplica el servidor) | Precio sugerido |
|---|---|---|---|
| `coins2x` | Monedas x2 | ×2 monedas al vender y en premios de misión | R$ 199 |
| `luckPlus` | Súper Suerte | +0.25 de suerte en todos los llenados (como un Perfecto extra) | R$ 349 |
| `bigBag` | Mochila Gigante | +50 espacios de inventario | R$ 149 |
| `vip` | VIP | Relleno Misterio gratis (sin los 100 por llenado), ×1.1 monedas, etiqueta 👑 | R$ 399 |

### Developer Products (consumibles, se pueden comprar muchas veces)
| key | Nombre | Efecto | Precio sugerido |
|---|---|---|---|
| `coinsS` | Bolsita de Monedas | +2.500 monedas | R$ 49 |
| `coinsM` | Cofre de Monedas | +12.000 monedas | R$ 199 |
| `coinsL` | Montaña de Monedas | +60.000 monedas | R$ 799 |
| `luck15` | Poción de Suerte | +0.5 de suerte por 15 min (se acumula) | R$ 99 |
| `legend1` | Molde de Oro | El próximo llenado sale Legendario sí o sí | R$ 249 |

Los números de los efectos están en `Monetization.EFFECTS`. Cambiar precios en Robux se hace en el
Creator Dashboard (la UI lee el precio real del Marketplace; `robux` en el config es solo respaldo).

## Paso a paso para activarlo

1. Publica el lugar: **File → Publish to Roblox** (hace falta para crear pases/productos).
2. Creator Dashboard → tu experiencia → **Monetization → Passes → Create a Pass**: crea los 4 pases
   (nombre, imagen, precio, "Item for sale" activado). Copia el **Pass ID** de cada uno.
3. **Monetization → Developer Products → Create**: crea los 5 productos. Copia cada **Product ID**.
4. Pega los ids en `roblox/src/shared/Config/Monetization.luau` (campo `id` de cada uno).
5. Studio → **Game Settings → Security → Enable Studio Access to API Services** (DataStore en Studio).

## Cómo probar

- **Con id = 0 (antes de crear nada)**: en Studio, al tocar un ítem de la pestaña ⭐ Robux se
  **simula** la compra (acción `devBuy`, solo funciona en Studio) y ves el efecto al instante.
- **Con ids reales**: en Studio la compra sale con el aviso "This is a test purchase" y no cobra.
- En el juego publicado, un ítem con id 0 aparece deshabilitado ("¡Muy pronto!").

## Cómo funciona por dentro (seguridad)

- `ProcessReceipt` es **idempotente**: guarda el `PurchaseId` en el perfil (`receipts`, últimos 60)
  y solo responde `PurchaseGranted` **después** de guardar en el DataStore. Si el guardado falla
  responde `NotProcessedYet` y Roblox lo reintenta; como el recibo ya está anotado, nunca se da doble.
- Los pases se consultan con `UserOwnsGamePassAsync` al entrar y se activan al instante con
  `PromptGamePassPurchaseFinished`.
- Todo efecto se aplica en el servidor (suerte, monedas, espacio). El cliente solo muestra.

## Políticas de Roblox (importante)

- **Ítems aleatorios pagados**: la Poción de Suerte y el Súper Suerte cambian las probabilidades de
  un resultado aleatorio. Roblox exige **mostrar las probabilidades** antes de pagar: el panel de la
  máquina ya muestra la tabla de rareza con la suerte actual incluida. No quites esa tabla.
- En países con reglas de "loot boxes" (p. ej. restricciones por región), Roblox puede bloquear
  ciertas compras aleatorias: usa `PolicyService:GetPolicyInfoForPlayerAsync` →
  `ArePaidRandomItemsRestricted` si decides vender algo 100% aleatorio a futuro.
- Público infantil: nada de presión engañosa ("¡últimos 5 minutos!" falsos, etc.).
