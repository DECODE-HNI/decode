// cross_impact.cypher  --  Cross-Impact-Wirkungsanalyse (2.2.2).
// Nutzt die v3.g-INFLUENCES-Matrix (sign x strength, engineering-reasoned).
// sign '+' = verbessert die Ziel-Kategorie, '-' = verschlechtert sie; strength 1..3.
// $mode:  'lever' (default) -> Wirkungen eines Hebels/einer Kategorie ($leverId)
//         'tradeoff'        -> Hebel, die >=2 Kategorien mit gemischten Vorzeichen treiben

// --- Modus 'lever' ---------------------------------------------------------
MATCH (src {id:$leverId})-[r:INFLUENCES]->(ic:ImpactCategory)
WHERE coalesce($mode,'lever') = 'lever'
RETURN 'lever'                    AS report,
       coalesce(src.name,src.id)  AS cause,
       labels(src)[0]             AS causeType,
       ic.name                    AS impactCategory,
       r.sign                     AS sign,
       r.strength                 AS strength,
       r.mechanism                AS mechanism
ORDER BY strength DESC, impactCategory

UNION

// --- Modus 'tradeoff' ----------------------------------------------------
MATCH (src)-[r:INFLUENCES]->(ic:ImpactCategory)
WHERE $mode = 'tradeoff'
WITH src, collect(DISTINCT r.sign) AS signs,
     collect(DISTINCT ic.name + ' [' + r.sign + toString(r.strength) + ']') AS cats
WHERE size(signs) > 1
RETURN 'tradeoff'                 AS report,
       coalesce(src.name,src.id)  AS cause,
       labels(src)[0]             AS causeType,
       reduce(s='', c IN cats | s + CASE WHEN s='' THEN '' ELSE ', ' END + c) AS impactCategory,
       null                       AS sign,
       size(cats)                 AS strength,
       'conflicting influences on the categories listed' AS mechanism
ORDER BY strength DESC, cause;
