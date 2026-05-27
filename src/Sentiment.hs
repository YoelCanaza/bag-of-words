-- =============================================================================
-- Sentiment.hs — Clasificador de Sentimiento por Análisis de Polaridad
-- =============================================================================
-- Universidad Nacional del Altiplano Puno — Ingeniería de Sistemas
-- Lenguajes de Programación — Unidad I: Big Data Funcional
--
-- Responsabilidad: evaluar el sentimiento de cada reseña comparando sus
-- palabras contra un diccionario heurístico de polaridad.
--
-- Concepto funcional aplicado:
--   FOLD (reduce) — acumula la puntuación de polaridad palabra a palabra
--                   sin variables de estado mutables ni bucles.
-- =============================================================================

module Sentiment
    ( sentimentDict
    , scoreWords
    , classifyScore
    , classifyReview
    , accuracyReport
    ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

-- ---------------------------------------------------------------------------
-- DICCIONARIO HEURÍSTICO DE SENTIMIENTO (Español)
-- Palabras positivas → +1  |  Palabras negativas → -1
-- ---------------------------------------------------------------------------

positiveWords :: [String]
positiveWords =
    [ "bueno","buena","buenos","buenas","excelente","increible"
    , "fantastico","maravilloso","genial","perfecto","recomiendo"
    , "mejor","feliz","amor","calidad","positivo","agradable"
    , "satisfecho","recomendable","unico","brillante","emocionante"
    , "espectacular","extraordinario","magnifico","sublime","hermoso"
    , "hermosa","encantador","fascinante","admirable","memorable"
    , "sorprendente","interesante","divertido","entretenido","bonito"
    , "bonita","precioso","preciosa","alegre","optimista","inspirador"
    , "poderoso","elegante","profundo","impresionante","cautivador"
    , "entretenida","divertida","apasionante","emotivo","conmovedor"
    , "recomendado","estupendo","notable","exquisito","fluido"
    , "original","creativo","innovador","autentico","sincero"
    ]

negativeWords :: [String]
negativeWords =
    [ "malo","mala","malos","malas","terrible","horrible","pesimo"
    , "decepcionante","peor","odio","triste","problema","falla"
    , "negativo","desagradable","insatisfecho","nunca","jamas"
    , "deplorable","mediocre","deficiente","aburrido","violencia"
    , "injusticia","cruel","brutal","sombrio","lamentable"
    , "frustrante","confuso","dificil","tedioso","irritante"
    , "aburrida","pesada","lento","lenta","innecesario","ridiculo"
    , "ridicula","estupido","estupida","insulso","insulsa","vacio"
    , "vacia","predecible","cliche","soporifero","mal","nefasto"
    , "catastrofico","desastre","fracaso","fallido","decepcion"
    , "perdida","tiempo","monotono","repetitivo","torpe","torpes"
    ]

-- ---------------------------------------------------------------------------
-- | Diccionario compilado: palabra → puntuación (+1 / -1)
-- ---------------------------------------------------------------------------
sentimentDict :: Map String Int
sentimentDict = Map.union positiveMap negativeMap
  where
    positiveMap = Map.fromList [(w,  1) | w <- positiveWords]
    negativeMap = Map.fromList [(w, -1) | w <- negativeWords]

-- ---------------------------------------------------------------------------
-- | Calcula la puntuación de polaridad de una lista de palabras.
--
--   FOLD puro: recorre la lista acumulando el score en un acumulador.
--   No hay variables mutables — el acumulador se pasa como argumento.
--
--   scoreWords ["excelente","pero","malo"] = 1 + 0 + (-1) = 0
-- ---------------------------------------------------------------------------
scoreWords :: [String] -> Int
scoreWords = foldl accumulate 0
  where
    accumulate acc word = acc + Map.findWithDefault 0 word sentimentDict
    --          ^^^                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    --          acumulador puro    lookup sin error si la palabra no existe

-- ---------------------------------------------------------------------------
-- | Clasifica una puntuación numérica en etiqueta de sentimiento.
--   Función pura — mismo input, siempre mismo output.
-- ---------------------------------------------------------------------------
classifyScore :: Int -> String
classifyScore score
    | score > 0 = "Positivo"
    | score < 0 = "Negativo"
    | otherwise  = "Neutro"

-- ---------------------------------------------------------------------------
-- | Pipeline completo para una sola reseña (lista de tokens limpios).
--   Compone scoreWords y classifyScore — sin efectos secundarios.
-- ---------------------------------------------------------------------------
classifyReview :: [String] -> String
classifyReview = classifyScore . scoreWords
--               ^^^^^^^^^^^^^^^^^^^^^^^
--               Composición de funciones (estilo funcional)

-- ---------------------------------------------------------------------------
-- | Calcula estadísticas de precisión comparando predicciones con etiquetas
--   reales.  Útil para la prueba de stress con IMDB (etiquetas conocidas).
--
--   Devuelve (correctos, total, porcentaje)
-- ---------------------------------------------------------------------------
accuracyReport :: [String]    -- etiquetas predichas por el clasificador
               -> [String]    -- etiquetas reales del dataset
               -> (Int, Int, Double)
accuracyReport predicted actual =
    let pairs    = zip predicted actual
        matches  = filter (uncurry eqLabel) pairs
        correct  = length matches
        total    = length pairs
        pct      = if total == 0 then 0.0
                   else fromIntegral correct * 100.0 / fromIntegral total
    in (correct, total, pct)
  where
    -- Normaliza etiquetas: "positivo"/"Positivo" → mismo resultado
    eqLabel p a = normalizeLabel p == normalizeLabel a

    normalizeLabel "positivo" = "Positivo"
    normalizeLabel "negativo" = "Negativo"
    normalizeLabel other      = other
