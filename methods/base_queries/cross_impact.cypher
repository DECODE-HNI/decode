// cross_impact.cypher  --  cross-impact analysis (2.2.2).
// Uses the v3.g INFLUENCES matrix (sign x strength, engineering-reasoned).
// sign '+' = improves the target category, '-' = worsens it; strength 1..3.
// $mode:  'lever' (default) -> effects of one lever/category ($leverId)
//         'tradeoff'        -> levers that drive >=2 categories with mixed signs

// --- mode 'lever' ----------------------------------------------------------
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

// --- mode 'tradeoff' -------------------------------------------------------
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
