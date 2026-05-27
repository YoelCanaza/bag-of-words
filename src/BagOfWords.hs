-- =============================================================================
-- BagOfWords.hs — Motor de Frecuencia de Vocabulario (Bag of Words)
-- =============================================================================
-- Universidad Nacional del Altiplano Puno — Ingeniería de Sistemas
-- Lenguajes de Programación — Unidad I: Big Data Funcional
--
-- Responsabilidad: construir el ranking de frecuencia global de palabras
-- (Bag of Words) aplicando filter y foldl sobre el corpus completo.
--
-- Conceptos funcionales aplicados:
--   FILTER — elimina palabras de ruido (stopwords, muy cortas, inválidas)
--   FOLD   — agrega la frecuencia de cada palabra sin estado mutable
-- =============================================================================

module BagOfWords
    ( isValidWord
    , filterWords
    , buildBoW
    , topN
    ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.List       (sortBy)
import Data.Ord        (comparing, Down(..))

-- ---------------------------------------------------------------------------
-- STOPWORDS en español
-- Incluye palabras < 4 caracteres y conectores comunes que no aportan
-- significado al análisis de vocabulario.
-- ---------------------------------------------------------------------------
stopwords :: [String]
stopwords =
    [ "de","la","el","en","y","a","que","los","del","las","un","una"
    , "con","por","se","no","es","lo","al","su","le","si","me","ya"
    , "mi","tu","te","hay","ser","fue","han","muy","son","pero","para"
    , "esta","como","todo","bien","este","sus","era","sin","ese","esa"
    , "eso","uno","dos","tres","solo","todo","toda","todos","todas"
    , "algo","aqui","alli","ahi","cada","otro","otra","ellos","ellas"
    , "esto","esta","esos","esas","unos","unas","cual","cuyos","cuyas"
    , "cuando","donde","aunque","sobre","entre","hasta","desde","hacia"
    , "ante","bajo","cabe","tras","segun","durante","mediante","versus"
    ]

-- ---------------------------------------------------------------------------
-- | Predicate: una palabra es válida para el Bag of Words si:
--   1. tiene 4 o más caracteres (elimina artículos y preposiciones cortos)
--   2. no está en la lista de stopwords
-- ---------------------------------------------------------------------------
isValidWord :: String -> Bool
isValidWord w = length w >= 4 && w `notElem` stopwords
--             ^^^^^^^^^^^^^     ^^^^^^^^^^^^^^^^^^^^^^^
--             filtro longitud   filtro stopwords

-- ---------------------------------------------------------------------------
-- | Filtra una lista de palabras manteniendo solo las válidas.
--   FILTER puro — ningún efecto secundario.
-- ---------------------------------------------------------------------------
filterWords :: [String] -> [String]
filterWords = filter isValidWord
--            ^^^^^^^^^^^^^^^^^^^
--            FILTER de orden superior — isValidWord como predicado

-- ---------------------------------------------------------------------------
-- | Construye el Bag of Words global desde el corpus completo.
--
--   Algoritmo MapReduce funcional:
--     foldl externo: reduce la lista de documentos
--     foldl interno: reduce la lista de palabras de cada documento
--     insertWith (+): agrega frecuencias sin variable de estado compartida
--
--   Tipo:  [[String]] → Map String Int
--          corpus     → { palabra → frecuencia }
-- ---------------------------------------------------------------------------
buildBoW :: [[String]] -> Map String Int
buildBoW = foldl foldDocument Map.empty
  where
    -- FOLD externo: acumula el Map a lo largo de todos los documentos
    foldDocument acc tokens = foldl insertWord acc tokens

    -- FOLD interno: inserta cada palabra en el mapa de frecuencias
    insertWord acc word = Map.insertWith (+) word 1 acc
    --                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    --                    REDUCE puro — (+) combina sin estado mutable

-- ---------------------------------------------------------------------------
-- | Extrae las N palabras más frecuentes del Bag of Words.
--   Ordena descendentemente por frecuencia usando comparación funcional.
-- ---------------------------------------------------------------------------
topN :: Int -> Map String Int -> [(String, Int)]
topN n = take n . sortBy (comparing (Down . snd)) . Map.toList
