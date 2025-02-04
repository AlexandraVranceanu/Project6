 -- Acest script SQL analizeaz? performan?a campaniilor publicitare din Facebook Ads ?i Google Ads, unind datele din ambele surse ?i calculând metrici relevante pentru evaluarea eficien?ei marketingului digital.

-- **Unificarea datelor din Facebook Ads ?i Google Ads**
WITH Table_join_unionall AS (
    -- Se selecteaz? datele din tabelul Facebook Ads, al?turând informa?iile despre campanii ?i adset-uri
    SELECT
        fabd.ad_date,
        fc.campaign_name,
        fabd.spend,
        fabd.impressions,
        fabd.reach,
        fabd.clicks,
        fabd.leads,
        fabd.value 
    FROM public.facebook_ads_basic_daily fabd 
    LEFT JOIN public.facebook_campaign fc ON fabd.campaign_id = fc.campaign_id 
    LEFT JOIN public.facebook_adset fa ON fabd.adset_id = fa.adset_id 
    
    UNION ALL 
    
    -- Se selecteaz? datele din Google Ads pentru a fi unite cu cele de la Facebook
    SELECT
        ad_date,
        campaign_name,
        spend,
        impressions,
        reach,
        clicks,
        leads,
        value 
    FROM public.google_ads_basic_daily
)

-- **Calcularea indicatorilor de performan??**
SELECT
    ad_date, 
    campaign_name,
    SUM(spend) AS sum_spend, -- Suma total? a cheltuielilor
    SUM(impressions) AS sum_impressions, -- Suma total? a afi??rilor
    SUM(reach) AS sum_reach, -- Suma total? a audien?ei unice
    SUM(clicks) AS sum_clicks, -- Suma total? a click-urilor
    SUM(leads) AS sum_leads, -- Suma total? a lead-urilor
    SUM(value) AS sum_value, -- Suma total? a valorii generate
    
    -- Calcularea Return on Marketing Investment (ROMI)
    CASE 
        WHEN SUM(spend) <> 0 THEN (SUM(value) - SUM(spend))::FLOAT / SUM(spend) * 100
    END AS ROMI,
    
    -- Calcularea Click-Through Rate (CTR)
    CASE 
        WHEN SUM(impressions) <> 0 THEN SUM(clicks)::FLOAT / SUM(impressions)
    END AS CTR,
    
    -- Calcularea Cost per Click (CPC)
    CASE 
        WHEN SUM(clicks) <> 0 THEN SUM(spend) / SUM(clicks)
    END AS CPC,
    
    -- Calcularea Cost per Mille (CPM) - costul la 1000 de afi??ri
    CASE
        WHEN SUM(impressions) <> 0 THEN 1000 * SUM(spend) / SUM(impressions)
    END AS CPM,
    
    -- Extragem luna ?i ziua pentru analiz? temporal?
    TO_CHAR(DATE_TRUNC('month', ad_date), 'MM-DD') AS new_month,
    
    -- Calcularea valorii CTR din luna precedent? pentru compara?ie
    LAG(
        CASE 
            WHEN SUM(impressions) <> 0 THEN SUM(clicks)::FLOAT / SUM(impressions)
        END
    ) OVER (PARTITION BY TO_CHAR(DATE_TRUNC('month', ad_date), 'MM-DD')) AS lag_ctr,
    
    -- Diferen?a procentual? a CTR fa?? de luna precedent?
    (CASE 
        WHEN SUM(impressions) <> 0 THEN SUM(clicks)::FLOAT / SUM(impressions)
    END) - LAG(
        CASE 
            WHEN SUM(impressions) <> 0 THEN SUM(clicks)::FLOAT / SUM(impressions)
        END
    ) OVER (PARTITION BY TO_CHAR(DATE_TRUNC('month', ad_date), 'MM-DD')) * 100 AS ctr_diff,
    
    -- Calcularea valorii CPM din luna precedent? pentru compara?ie
    LAG(
        CASE 
            WHEN SUM(impressions) <> 0 THEN 1000 * SUM(spend) / SUM(impressions)
        END
    ) OVER (PARTITION BY TO_CHAR(DATE_TRUNC('month', ad_date), 'MM-DD')) AS lag_cpm,
    
    -- Diferen?a procentual? a CPM fa?? de luna precedent?
    (CASE 
        WHEN SUM(impressions) <> 0 THEN 1000 * SUM(spend) / SUM(impressions)
    END) - LAG(
        CASE 
            WHEN SUM(impressions) <> 0 THEN 1000 * SUM(spend) / SUM(impressions)
        END
    ) OVER (PARTITION BY TO_CHAR(DATE_TRUNC('month', ad_date), 'MM-DD')) * 100 AS cpm_diff,
    
    -- Calcularea valorii ROMI din luna precedent? pentru compara?ie
    LAG(
        CASE 
            WHEN SUM(spend) <> 0 THEN (SUM(value) - SUM(spend))::FLOAT / SUM(spend) * 100
        END
    ) OVER (PARTITION BY TO_CHAR(DATE_TRUNC('month', ad_date), 'MM-DD')) AS lag_romi,
    
    -- Diferen?a procentual? a ROMI fa?? de luna precedent?
    (CASE 
        WHEN SUM(spend) <> 0 THEN (SUM(value) - SUM(spend))::FLOAT / SUM(spend) * 100
    END) - LAG(
        CASE 
            WHEN SUM(spend) <> 0 THEN (SUM(value) - SUM(spend))::FLOAT / SUM(spend) * 100
        END
    ) OVER (PARTITION BY TO_CHAR(DATE_TRUNC('month', ad_date), 'MM-DD')) AS romi_diff
FROM Table_join_unionall
GROUP BY ad_date, campaign_name
ORDER BY ad_date;