-- =============================================================================
-- Sentiment.hs — Clasificador de Sentimiento por Análisis de Polaridad
-- =============================================================================
-- Universidad Nacional del Altiplano Puno — Ingeniería de Sistemas
-- Lenguajes de Programación — Unidad I: Big Data Funcional
--
-- Responsabilidad: evaluar el sentimiento de cada reseña comparando sus
-- palabras contra un diccionario heurístico de polaridad.
--
-- Conceptos funcionales aplicados:
--   FOLD (reduce) — acumula la puntuación de polaridad palabra a palabra
--                   sin variables de estado mutables ni bucles.
--   Composición   — normalizeToken . scoreWords . classifyScore
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
-- NORMALIZACIÓN DE TOKENS PARA MATCHING
-- Elimina tildes antes de comparar contra el diccionario.
-- Así "película" y "pelicula", "emoción" y "emocion" son equivalentes.
-- El BoW sigue mostrando las palabras con tilde — solo se normaliza
-- para la búsqueda en el diccionario de sentimiento.
-- ---------------------------------------------------------------------------

stripAccent :: Char -> Char
stripAccent 'á' = 'a'; stripAccent 'Á' = 'a'
stripAccent 'é' = 'e'; stripAccent 'É' = 'e'
stripAccent 'í' = 'i'; stripAccent 'Í' = 'i'
stripAccent 'ó' = 'o'; stripAccent 'Ó' = 'o'
stripAccent 'ú' = 'u'; stripAccent 'Ú' = 'u'
stripAccent 'ü' = 'u'; stripAccent 'Ü' = 'u'
stripAccent 'ñ' = 'n'; stripAccent 'Ñ' = 'n'
stripAccent  c  =  c

normalizeToken :: String -> String
normalizeToken = map stripAccent

-- ---------------------------------------------------------------------------
-- NEGADORES — palabras que invierten el sentimiento de la siguiente palabra
-- Se detectan en el stream RAW (antes del filtro de longitud >= 4),
-- por eso se manejan aquí y no en BagOfWords.
-- ---------------------------------------------------------------------------

negators :: [String]
negators =
    [ "no","ni","sin","nunca","jamas","tampoco"
    , "nada","nadie","ninguna","ningun","ninguno","ningumas"
    ]

-- ---------------------------------------------------------------------------
-- DICCIONARIO HEURÍSTICO DE SENTIMIENTO (Español, sin tildes)
-- ~100 palabras positivas + ~100 palabras negativas
-- Enfocado en vocabulario de reseñas cinematográficas y de servicios.
-- ---------------------------------------------------------------------------

positiveWords :: [String]
positiveWords =
    -- Calificativos generales
    [ "bueno","buena","buenos","buenas","bien","gran","grande","grandes"
    , "excelente","excelentes","genial","geniales"
    , "perfecto","perfecta","perfectos","perfectas"
    , "fantastico","fantastica","fantasticos","fantasticas"
    , "maravilloso","maravillosa","maravillosos","maravillosas"
    , "increible","increibles","espectacular","espectaculares"
    , "extraordinario","extraordinaria","extraordinarios"
    , "magnifico","magnifica","magnificos","magnificas"
    , "sublime","sublimes","excepcional","excepcionales"
    -- Calificativos de calidad
    , "brillante","brillantes","magistral","magistrales"
    , "notable","notables","sobresaliente","sobresalientes"
    , "impresionante","impresionantes","sorprendente","sorprendentes"
    , "cautivador","cautivadora","fascinante","fascinantes"
    , "apasionante","apasionantes","emocionante","emocionantes"
    , "memorable","memorables","unico","unica","unicos","unicas"
    , "original","originales","creativo","creativa","creativos"
    , "innovador","innovadora","autentico","autentica","autenticos"
    , "solido","solida","solidos","solidas"
    -- Emociones positivas
    , "hermoso","hermosa","hermosos","hermosas"
    , "bello","bella","bellos","bellas"
    , "lindo","linda","lindos","lindas"
    , "precioso","preciosa","preciosos","preciosas"
    , "encantador","encantadora","encantadores"
    , "divertido","divertida","divertidos","divertidas"
    , "emotivo","emotiva","emotivos","emotivas"
    , "conmovedor","conmovedora","conmovedores"
    , "tierno","tierna","tiernos","tiernas"
    , "alegre","alegres","feliz","felices"
    , "esperanzador","esperanzadora","inspirador","inspiradora"
    -- Narrativa y arte
    , "interesante","interesantes","profundo","profunda","profundos"
    , "inteligente","inteligentes","convincente","convincentes"
    , "coherente","coherentes","verosimil","verosimiles"
    , "realista","realistas","natural","naturales"
    , "poderoso","poderosa","poderosos","poderosas"
    , "talentoso","talentosa","talentosos","talentosas"
    , "dinamico","dinamica","dinamicos","dinamicas"
    -- Verbos y expresiones
    , "recomiendo","recomendable","recomendables","recomendado"
    , "disfrute","disfrutar","disfruta","disfrutan"
    , "encanto","encantan","encanta","encantaron"
    , "gusto","gustan","gusta","gustaron","agrado","agrada"
    , "adoro","adora","adoran","adorable","adorables"
    , "sorprendio","sorprendieron","emociono","emocionaron"
    -- Calidad técnica
    , "fluido","fluida","fluidos","espectacular","impecable"
    , "cuidado","cuidada","cuidados","detallado","detallada"
    , "clasico","clasica","clasicos","clasicas"
    -- Lexicon de cine positivo
    , "joya","joyas","obra","maestra","maestro","tesoro","tesoros"
    , "especial","especiales","amor","adorable","adorables"
    , "aclamado","aclamada","satisfactorio","satisfactoria"
    , "placentero","placentera","logrado","lograda"
    , "entretenimiento","disfrutable","agradece","deleitoso"
    , "recomiendo","recomienda","recomiendan","merece","merecia"
    ]

negativeWords :: [String]
negativeWords =
    -- Calificativos generales
    [ "malo","mala","malos","malas","mal"
    , "terrible","terribles","horrible","horribles"
    , "pesimo","pesima","pesimos","pesimas"
    , "nefasto","nefasta","nefastos","nefastas"
    , "penoso","penosa","penosos","penosas"
    , "vergonzoso","vergonzosa","vergonzosos"
    , "deplorable","deplorables","lamentable","lamentables"
    , "catastrofico","catastrofica","catastroficos"
    , "desastroso","desastrosa","desastrosos"
    , "miserable","miserables","detestable","detestables"
    , "odioso","odiosa","odiosos","odiosas"
    , "repugnante","repugnantes","insoportable","insoportables"
    -- Calificativos de calidad
    , "mediocre","mediocres","deficiente","deficientes"
    , "aburrido","aburrida","aburridos","aburridas"
    , "tedioso","tediosa","tediosos","tediosas"
    , "soso","sosa","sosos","sosas","insulso","insulsa"
    , "monotono","monotona","monotonos","monotonas"
    , "repetitivo","repetitiva","repetitivos","repetitivas"
    , "predecible","predecibles","cliche"
    , "superficial","superficiales","simplista","simplistas"
    , "vacio","vacia","vacios","vacias"
    , "plano","plana","planos","planas"
    , "soporifero","soporifera","soporiferos"
    , "trillado","trillada","trillados","trilladas"
    -- Narrativa y actuación
    , "ridiculo","ridicula","ridiculos","ridiculas"
    , "absurdo","absurda","absurdos","absurdas"
    , "incoherente","incoherentes","confuso","confusa"
    , "exagerado","exagerada","exagerados","exageradas"
    , "forzado","forzada","forzados","forzadas"
    , "sobreactuado","sobreactuada","sobreactuados"
    , "caricaturesco","caricaturesca"
    , "falso","falsa","falsos","falsas"
    , "torpe","torpes","incompetente","incompetentes"
    -- Decepciones
    , "decepcionante","decepcionantes","frustrante","frustrantes"
    , "irritante","irritantes","molesto","molesta"
    , "desagradable","desagradables","aburre","aburren"
    , "decepciono","decepcionaron","fallo","fallaron"
    , "arrepiento","arrepentido","arrepentida"
    -- Basura / términos fuertes
    , "basura","porqueria","bodrio","desastre","fracaso"
    , "innecesario","innecesaria","innecesarios"
    , "perdida","desperdicio","malgasto"
    , "estupido","estupida","estupidos","estupidas"
    , "idiota","idiotas","ridiculas"
    -- Lexicon de cine negativo — palabras de alta frecuencia en críticas
    , "peor","peores"                                 -- comparativo negativo
    , "odio","odia","odian","odiar","odie","odio"     -- hate
    , "detesto","detesta","detestan","detestar"
    , "patetico","patetica","pateticos","pateticas"
    , "espantoso","espantosa","espantosos","espantosas"
    , "atroz","atroces"
    , "deprimente","deprimentes","depresivo","depresiva"
    , "inutil","inutiles"
    , "infame","infames","asqueroso","asquerosa"
    , "verguenza","decepcion","fraude","estafa"
    , "fallido","fallida","fallidos","fallidas"
    , "pobre","pobres"                                -- pobre historia/actuacion
    , "debil","debiles","flojo","floja","flojos","flojas"
    , "desaprovechado","desaprovechada"
    , "catastrofe","vergonzosas","nauseabunda"
    , "robo","estupidez","incoherencias","disparate"
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
-- | Calcula la puntuación de polaridad con manejo de negación.
--
--   FOLD puro con estado de dos componentes (negationFlag, score):
--   - Si la palabra es un negador → activa la bandera de negación
--   - Si la siguiente palabra tiene valor semántico → invierte el signo
--   - El acumulador se pasa como argumento — sin variables mutables
--
--   Ejemplo:
--     scoreWords ["no","fue","buena"] = 0 + 0 + (-1) = -1  ← negación
--     scoreWords ["fue","buena"]      = 0 + 0 +  1   = +1  ← sin negación
-- ---------------------------------------------------------------------------
scoreWords :: [String] -> Int
scoreWords ws = snd $ foldl step (False, 0) ws
  where
    step (negated, acc) w
      -- Negador detectado: activa bandera, no suma puntuación
      | w `elem` negators =
          (True, acc)
      -- Palabra con valor semántico: aplica el signo (posiblemente invertido)
      | otherwise =
          let norm  = normalizeToken w
              value = Map.findWithDefault 0 norm sentimentDict
              score = if negated && value /= 0 then -value else value
          in (False, acc + score)
    --  ^^^^^^^^^^^^^^^^^^^^^^^^
    --  FOLD: (Bool, Int) → String → (Bool, Int)
    --  acumulador puro — nunca modifica variables externas

-- ---------------------------------------------------------------------------
-- | Clasifica una puntuación numérica en etiqueta de sentimiento.
-- ---------------------------------------------------------------------------
classifyScore :: Int -> String
classifyScore score
    | score > 0 = "Positivo"
    | score < 0 = "Negativo"
    | otherwise  = "Neutro"

-- ---------------------------------------------------------------------------
-- | Pipeline completo para una sola reseña (tokens crudos, incluyendo
--   negadores de 2-3 letras que el filtro de BoW descartaría).
-- ---------------------------------------------------------------------------
classifyReview :: [String] -> String
classifyReview = classifyScore . scoreWords

-- ---------------------------------------------------------------------------
-- | Reporte de precisión contra etiquetas reales del dataset IMDB.
-- ---------------------------------------------------------------------------
accuracyReport :: [String] -> [String] -> (Int, Int, Double)
accuracyReport predicted actual =
    let pairs   = zip predicted actual
        correct = length $ filter (uncurry eqLabel) pairs
        total   = length pairs
        p       = if total == 0 then 0.0
                  else fromIntegral correct * 100.0 / fromIntegral total
    in (correct, total, p)
  where
    eqLabel p a = normalizeLabel p == normalizeLabel a
    normalizeLabel "positivo" = "Positivo"
    normalizeLabel "negativo" = "Negativo"
    normalizeLabel other      = other
