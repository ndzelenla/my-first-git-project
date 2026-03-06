(Guided) dbt Transformation Project
Author: Sammy Ndzelen
Date: 06.03.2026


## Part 1: Project Setup (Estimated: 10 minutes)
# Task 1: Write dbt_project.yml

# dbt_project.yml
name: 'streampulse'
version: '1.0.0'
config-version: 2

profile: 'streampulse'

# Define model configurations:
# - Staging: materialized as views, schema = staging
# - Intermediate: materialized as views, schema = analytics
# - Marts: materialized as tables, schema = marts

models:
  streampulse:
    +materialized: table
    +persist_docs:
      relation: true
      columns: true
    
    staging:
      +materialized: view
      +schema: staging
      +tags: ["staging", "hourly"]
    
    intermediate:
      +materialized: view
      +schema: analytics
      +tags: ["intermediate", "daily"]
    
    marts:
      +materialized: table
      +schema: marts
      +tags: ["marts", "critical"]

# Define test severity levels
tests:
  +severity: WARN
  +store_failures: true
  +schema: dbt_test_results

# Clean targets
clean-targets:
  - "target"
  - "dbt_packages"


## Task 2: Write packages.yml
# packages.yml — External packages

packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1
    
  - package: calogica/dbt_date
    version: 0.10.1
    
  - package: calogica/dbt_expectations
    version: 0.10.0



## Task: Write _staging_sources.yml
# models/staging/_staging_sources.yml

version: 2

sources:
  - name: raw
    database: STREAMPULSE_PROD
    schema: RAW
    description: "Raw data loaded from external sources"
    loader: Snowpipe
    loaded_at_field: _loaded_at
    
    freshness:
      warn_after: {count: 1, period: hour}
      error_after: {count: 6, period: hour}

    tables:
      - name: raw_events
        description: "User interaction events (streaming via Snowpipe)"
        columns:
          - name: event_id
            description: "Unique event identifier"
            tests:
              - not_null
              - unique
          - name: user_id
            description: "User identifier (foreign key to users)"
          - name: content_id
            description: "Content identifier (foreign key to content)"
          - name: event_type
            description: "Type of event: play, pause, complete, etc."
          - name: event_timestamp
            description: "When the event occurred"
          - name: device_type
            description: "Device used: mobile, desktop, tablet, tv"
          - name: country_code
            description: "2-letter country code"
          - name: watch_seconds
            description: "Seconds watched for this event"
          - name: _loaded_at
            description: "Snowpipe ingestion timestamp"

      - name: raw_users
        description: "User profile data from billing system"
        loaded_at_field: _loaded_at
        freshness:
          warn_after: {count: 24, period: hour}
          error_after: {count: 72, period: hour}
        columns:
          - name: user_id
            description: "Unique user identifier"
            tests:
              - not_null
              - unique
          - name: email
            description: "User email address"
          - name: signup_date
            description: "Date when user signed up"
          - name: country_code
            description: "2-letter country code"
          - name: preferred_language
            description: "User's preferred language"
          - name: marketing_opt_in
            description: "Whether user opted into marketing"

      - name: raw_content
        description: "Content catalog (shows, episodes, genres)"
        columns:
          - name: content_id
            description: "Unique content identifier"
            tests:
              - not_null
              - unique
          - name: show_id
            description: "Parent show identifier"
          - name: title
            description: "Content title"
          - name: genre
            description: "Content genre"
          - name: release_date
            description: "Release date"
          - name: duration_minutes
            description: "Duration in minutes"
          - name: season_number
            description: "Season number (for TV shows)"
          - name: episode_number
            description: "Episode number (for TV shows)"
          - name: content_type
            description: "Movie or Episode"

      - name: raw_subscriptions
        description: "Subscription lifecycle events"
        loaded_at_field: _loaded_at
        freshness:
          warn_after: {count: 24, period: hour}
          error_after: {count: 72, period: hour}
        columns:
          - name: subscription_id
            description: "Unique subscription identifier"
            tests:
              - not_null
          - name: user_id
            description: "User identifier"
          - name: event_type
            description: "created, renewed, cancelled, upgraded, downgraded"
          - name: event_timestamp
            description: "When the event occurred"
          - name: plan_id
            description: "Subscription plan identifier"
          - name: monthly_price
            description: "Monthly price at time of event"

      - name: raw_api_data
        description: "Third-party API data (social metrics)"
        loaded_at_field: _loaded_at
        freshness:
          warn_after: {count: 6, period: hour}
          error_after: {count: 24, period: hour}
        columns:
          - name: api_response_id
            description: "Unique response identifier"
          - name: content_id
            description: "Content identifier"
          - name: api_name
            description: "Source API name"
          - name: response_data
            description: "JSON response data (VARIANT type)"
          - name: retrieved_at
            description: "When data was retrieved"



## Part 3: Staging Models (Estimated: 20 minutes)
Write all five staging models.

# Model 1: stg_events.sql
-- models/staging/stg_events.sql
-- Purpose: Clean, type, and deduplicate raw user events

WITH source AS (
    SELECT *
    FROM {{ source('raw', 'raw_events') }}
    WHERE event_id IS NOT NULL
      AND user_id IS NOT NULL
),

deduplicated AS (
    SELECT
        event_id,
        user_id,
        content_id,
        LOWER(TRIM(event_type)) AS event_type,
        CAST(event_timestamp AS TIMESTAMP) AS event_timestamp,
        LOWER(TRIM(device_type)) AS device_type,
        UPPER(TRIM(country_code)) AS country_code,
        CAST(watch_seconds AS INTEGER) AS watch_seconds,
        _loaded_at,
        ROW_NUMBER() OVER (
            PARTITION BY event_id 
            ORDER BY _loaded_at DESC
        ) AS rn
    FROM source
)

SELECT
    event_id,
    user_id,
    content_id,
    event_type,
    event_timestamp,
    device_type,
    country_code,
    watch_seconds,
    _loaded_at,
    -- Add derived columns
    DATE(event_timestamp) AS event_date,
    EXTRACT(HOUR FROM event_timestamp) AS event_hour,
    CASE
        WHEN watch_seconds >= 0 AND watch_seconds < 60 THEN 'short'
        WHEN watch_seconds >= 60 AND watch_seconds < 600 THEN 'medium'
        WHEN watch_seconds >= 600 THEN 'long'
    END AS watch_session_length
FROM deduplicated
WHERE rn = 1




## Model 2: stg_users.sql
-- models/staging/stg_users.sql
-- Purpose: Clean user profiles, normalize country codes

WITH source AS (
    SELECT *
    FROM {{ source('raw', 'raw_users') }}
    WHERE user_id IS NOT NULL
),

filtered AS (
    SELECT *
    FROM source
    WHERE email NOT LIKE '%@test.%'
      AND email NOT LIKE '%testuser%'
),

deduplicated AS (
    SELECT
        user_id,
        LOWER(TRIM(email)) AS email,
        CAST(signup_date AS DATE) AS signup_date,
        UPPER(TRIM(country_code)) AS country_code,
        LOWER(TRIM(preferred_language)) AS preferred_language,
        CAST(marketing_opt_in AS BOOLEAN) AS marketing_opt_in,
        _loaded_at,
        ROW_NUMBER() OVER (
            PARTITION BY user_id 
            ORDER BY _loaded_at DESC
        ) AS rn
    FROM filtered
),

country_normalized AS (
    SELECT
        *,
        CASE
            WHEN LENGTH(country_code) = 2 THEN country_code
            WHEN country_code = 'UNITED STATES' THEN 'US'
            WHEN country_code = 'UNITED KINGDOM' THEN 'GB'
            WHEN country_code = 'CANADA' THEN 'CA'
            ELSE 'XX'
        END AS normalized_country_code
    FROM deduplicated
)

SELECT
    user_id,
    email,
    signup_date,
    normalized_country_code AS country_code,
    preferred_language,
    marketing_opt_in,
    _loaded_at,
    -- Derived columns
    DATE_PART('day', CURRENT_DATE - signup_date) AS account_age_days,
    EXTRACT(YEAR FROM signup_date) AS signup_year,
    EXTRACT(MONTH FROM signup_date) AS signup_month
FROM country_normalized
WHERE rn = 1



## Model 3: stg_content.sql
-- models/staging/stg_content.sql
-- Purpose: Clean content catalog data

WITH source AS (
    SELECT *
    FROM {{ source('raw', 'raw_content') }}
    WHERE content_id IS NOT NULL
),

deduplicated AS (
    SELECT
        CAST(content_id AS INTEGER) AS content_id,
        CAST(show_id AS INTEGER) AS show_id,
        TRIM(title) AS title,
        TRIM(genre) AS genre,
        CAST(release_date AS DATE) AS release_date,
        CAST(duration_minutes AS INTEGER) AS duration_minutes,
        CAST(season_number AS INTEGER) AS season_number,
        CAST(episode_number AS INTEGER) AS episode_number,
        LOWER(TRIM(content_type)) AS content_type,
        _loaded_at,
        ROW_NUMBER() OVER (
            PARTITION BY content_id 
            ORDER BY _loaded_at DESC
        ) AS rn
    FROM source
),

genre_standardized AS (
    SELECT
        *,
        CASE
            WHEN LOWER(genre) LIKE '%comedy%' THEN 'Comedy'
            WHEN LOWER(genre) LIKE '%drama%' THEN 'Drama'
            WHEN LOWER(genre) LIKE '%action%' THEN 'Action'
            WHEN LOWER(genre) LIKE '%documentary%' THEN 'Documentary'
            WHEN LOWER(genre) LIKE '%reality%' THEN 'Reality TV'
            WHEN LOWER(genre) LIKE '%sci-fi%' OR LOWER(genre) LIKE '%science fiction%' THEN 'Sci-Fi'
            WHEN LOWER(genre) LIKE '%horror%' THEN 'Horror'
            WHEN LOWER(genre) LIKE '%romance%' THEN 'Romance'
            WHEN LOWER(genre) LIKE '%thriller%' THEN 'Thriller'
            WHEN LOWER(genre) LIKE '%kids%' OR LOWER(genre) LIKE '%children%' THEN 'Kids'
            ELSE 'Other'
        END AS genre_category,
        CASE
            WHEN release_date > CURRENT_DATE THEN CURRENT_DATE
            ELSE release_date
        END AS release_date_clean
    FROM deduplicated
)

SELECT
    content_id,
    show_id,
    title,
    genre,
    genre_category,
    release_date_clean AS release_date,
    duration_minutes,
    season_number,
    episode_number,
    content_type,
    _loaded_at,
    -- Derived columns
    CASE
        WHEN content_type = 'episode' THEN TRUE
        ELSE FALSE
    END AS is_episode,
    CASE
        WHEN duration_minutes <= 30 THEN 'short_form'
        WHEN duration_minutes <= 60 THEN 'medium_form'
        ELSE 'long_form'
    END AS content_length_category,
    DATE_PART('day', CURRENT_DATE - release_date_clean) AS days_since_release
FROM genre_standardized
WHERE rn = 1



## Model 4: stg_subscriptions.sql
-- models/staging/stg_subscriptions.sql
-- Purpose: Clean subscription lifecycle events

WITH source AS (
    SELECT *
    FROM {{ source('raw', 'raw_subscriptions') }}
    WHERE subscription_id IS NOT NULL
),

deduplicated AS (
    SELECT
        subscription_id,
        CAST(user_id AS INTEGER) AS user_id,
        LOWER(TRIM(event_type)) AS event_type,
        CAST(event_timestamp AS TIMESTAMP) AS event_timestamp,
        CAST(plan_id AS INTEGER) AS plan_id,
        CAST(monthly_price AS DECIMAL(10,2)) AS monthly_price,
        _loaded_at,
        ROW_NUMBER() OVER (
            PARTITION BY subscription_id, event_type, event_timestamp
            ORDER BY _loaded_at DESC
        ) AS rn
    FROM source
),

event_standardized AS (
    SELECT
        *,
        CASE event_type
            WHEN 'created' THEN 'new'
            WHEN 'renewed' THEN 'renewal'
            WHEN 'cancelled' THEN 'churn'
            WHEN 'upgraded' THEN 'upgrade'
            WHEN 'downgraded' THEN 'downgrade'
            ELSE event_type
        END AS event_category,
        CASE
            WHEN event_type IN ('created', 'renewed', 'upgraded') THEN 'active'
            WHEN event_type = 'cancelled' THEN 'churned'
            ELSE 'other'
        END AS subscription_status
    FROM deduplicated
)

SELECT
    subscription_id,
    user_id,
    event_type,
    event_category,
    subscription_status,
    event_timestamp,
    DATE(event_timestamp) AS event_date,
    plan_id,
    monthly_price,
    _loaded_at
FROM event_standardized
WHERE rn = 1
ORDER BY user_id, subscription_id, event_timestamp



## Model 5: stg_api_data.sql
-- models/staging/stg_api_data.sql
-- Purpose: Flatten and clean API response data

WITH source AS (
    SELECT *
    FROM {{ source('raw', 'raw_api_data') }}
),

flattened AS (
    SELECT
        api_response_id,
        CAST(content_id AS INTEGER) AS content_id,
        api_name,
        retrieved_at,
        -- Extract fields from JSON with null handling
        response_data:likes::INTEGER AS likes,
        response_data:shares::INTEGER AS shares,
        response_data:comments::INTEGER AS comments,
        response_data:views::INTEGER AS api_views,
        response_data:engagement_rate::FLOAT AS engagement_rate,
        response_data:sentiment_score::FLOAT AS sentiment_score,
        response_data:top_countries::ARRAY AS top_countries,
        response_data:demographics AS demographics,
        -- Extract nested fields
        response_data:demographics:age_18_24::FLOAT AS demo_age_18_24,
        response_data:demographics:age_25_34::FLOAT AS demo_age_25_34,
        response_data:demographics:age_35_44::FLOAT AS demo_age_35_44,
        response_data:demographics:age_45_plus::FLOAT AS demo_age_45_plus,
        response_data:demographics:male::FLOAT AS demo_male,
        response_data:demographics:female::FLOAT AS demo_female,
        _loaded_at
    FROM source
),

with_defaults AS (
    SELECT
        api_response_id,
        content_id,
        api_name,
        retrieved_at,
        COALESCE(likes, 0) AS likes,
        COALESCE(shares, 0) AS shares,
        COALESCE(comments, 0) AS comments,
        COALESCE(api_views, 0) AS api_views,
        COALESCE(engagement_rate, 0.0) AS engagement_rate,
        sentiment_score,
        top_countries,
        demographics,
        COALESCE(demo_age_18_24, 0.0) AS demo_age_18_24,
        COALESCE(demo_age_25_34, 0.0) AS demo_age_25_34,
        COALESCE(demo_age_35_44, 0.0) AS demo_age_35_44,
        COALESCE(demo_age_45_plus, 0.0) AS demo_age_45_plus,
        COALESCE(demo_male, 0.0) AS demo_male,
        COALESCE(demo_female, 0.0) AS demo_female,
        _loaded_at
    FROM flattened
),

deduplicated AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY content_id, api_name, DATE(retrieved_at)
            ORDER BY retrieved_at DESC
        ) AS rn
    FROM with_defaults
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['content_id', 'api_name', 'retrieved_at']) }} AS api_metrics_id,
    content_id,
    api_name,
    retrieved_at,
    DATE(retrieved_at) AS metric_date,
    likes,
    shares,
    comments,
    api_views,
    engagement_rate,
    sentiment_score,
    top_countries,
    -- Derived metrics
    likes + shares + comments AS total_engagements,
    CASE
        WHEN api_views > 0 THEN (likes + shares + comments) / api_views
        ELSE 0
    END AS engagement_per_view,
    _loaded_at
FROM deduplicated
WHERE rn = 1



## Part 4: Intermediate Models
# Model 1: int_user_sessions.sql
-- models/intermediate/int_user_sessions.sql
-- Purpose: Sessionize user events into 30-minute session windows

WITH events AS (
    SELECT
        user_id,
        event_id,
        event_timestamp,
        event_type,
        content_id,
        device_type,
        country_code,
        watch_seconds,
        LEAD(event_timestamp) OVER (
            PARTITION BY user_id 
            ORDER BY event_timestamp
        ) AS next_event_timestamp
    FROM {{ ref('stg_events') }}
),

session_boundaries AS (
    SELECT
        *,
        CASE
            WHEN {{ dbt_date.datediff('event_timestamp', 'next_event_timestamp', 'minute') }} > 30 
                 OR next_event_timestamp IS NULL
            THEN 1 ELSE 0
        END AS is_session_end,
        CASE
            WHEN {{ dbt_date.datediff('LAG(event_timestamp) OVER (PARTITION BY user_id ORDER BY event_timestamp)', 'event_timestamp', 'minute') }} > 30
                 OR LAG(event_timestamp) OVER (PARTITION BY user_id ORDER BY event_timestamp) IS NULL
            THEN 1 ELSE 0
        END AS is_session_start
    FROM events
),

session_numbers AS (
    SELECT
        *,
        SUM(is_session_start) OVER (
            PARTITION BY user_id 
            ORDER BY event_timestamp
            ROWS UNBOUNDED PRECEDING
        ) AS session_number
    FROM session_boundaries
),

sessions AS (
    SELECT
        user_id,
        session_number,
        MIN(event_timestamp) AS session_started_at,
        MAX(event_timestamp) AS session_ended_at,
        COUNT(DISTINCT event_id) AS event_count,
        COUNT(DISTINCT content_id) AS content_items_viewed,
        COUNT(DISTINCT CASE WHEN event_type = 'play' THEN content_id END) AS plays,
        SUM(watch_seconds) AS total_watch_seconds,
        MODE() WITHIN GROUP (ORDER BY device_type) AS device_type,
        MODE() WITHIN GROUP (ORDER BY country_code) AS country
    FROM session_numbers
    GROUP BY 1, 2
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['user_id', 'session_number']) }} AS session_id,
    user_id,
    session_number,
    session_started_at,
    session_ended_at,
    {{ dbt_date.datediff('session_started_at', 'session_ended_at', 'second') }} AS session_duration_seconds,
    event_count,
    content_items_viewed,
    plays,
    total_watch_seconds,
    device_type,
    country,
    CASE
        WHEN {{ dbt_date.datediff('session_started_at', 'session_ended_at', 'minute') }} < 5 THEN 'bounce'
        WHEN {{ dbt_date.datediff('session_started_at', 'session_ended_at', 'minute') }} < 15 THEN 'short'
        WHEN {{ dbt_date.datediff('session_started_at', 'session_ended_at', 'minute') }} < 30 THEN 'medium'
        ELSE 'long'
    END AS session_length_category
FROM sessions




##  Model 2: int_content_metrics.sql
-- models/intermediate/int_content_metrics.sql
-- Purpose: Daily content viewing metrics

WITH daily_events AS (
    SELECT
        content_id,
        DATE(event_timestamp) AS metric_date,
        COUNT(DISTINCT CASE WHEN event_type = 'play' THEN event_id END) AS plays,
        COUNT(DISTINCT CASE WHEN event_type = 'complete' THEN event_id END) AS completions,
        COUNT(DISTINCT user_id) AS unique_viewers,
        SUM(CASE WHEN event_type = 'play' THEN 1 ELSE 0 END) AS total_views,
        SUM(watch_seconds) AS total_watch_seconds,
        AVG(CASE WHEN watch_seconds > 0 THEN watch_seconds END) AS avg_watch_seconds,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY watch_seconds) AS median_watch_seconds
    FROM {{ ref('stg_events') }}
    WHERE content_id IS NOT NULL
    GROUP BY 1, 2
),

content_info AS (
    SELECT
        content_id,
        title,
        genre,
        duration_minutes,
        content_type
    FROM {{ ref('stg_content') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['d.content_id', 'd.metric_date']) }} AS content_metric_id,
    d.content_id,
    c.title,
    c.genre,
    c.content_type,
    d.metric_date,
    d.plays,
    d.completions,
    d.unique_viewers,
    d.total_views,
    d.total_watch_seconds,
    d.avg_watch_seconds,
    d.median_watch_seconds,
    -- Derived metrics
    CASE 
        WHEN d.total_views > 0 
        THEN d.completions / d.total_views 
        ELSE 0 
    END AS completion_rate,
    CASE
        WHEN c.duration_minutes > 0
        THEN (d.total_watch_seconds / 60.0) / c.duration_minutes
        ELSE 0
    END AS total_equivalent_viewings,
    d.total_watch_seconds / 3600.0 AS total_watch_hours,
    d.total_views / NULLIF(d.unique_viewers, 0) AS avg_views_per_viewer
FROM daily_events d
LEFT JOIN content_info c ON d.content_id = c.content_id



## Model 3: int_subscription_events.sql
-- models/intermediate/int_subscription_events.sql
-- Purpose: Derive subscription status from lifecycle events

WITH ordered_events AS (
    SELECT
        subscription_id,
        user_id,
        event_type,
        event_category,
        event_timestamp,
        event_date,
        plan_id,
        monthly_price,
        _loaded_at,
        LEAD(event_timestamp) OVER (
            PARTITION BY subscription_id 
            ORDER BY event_timestamp
        ) AS next_event_timestamp,
        LEAD(event_type) OVER (
            PARTITION BY subscription_id 
            ORDER BY event_timestamp
        ) AS next_event_type
    FROM {{ ref('stg_subscriptions') }}
),

status_durations AS (
    SELECT
        *,
        COALESCE(next_event_timestamp, CURRENT_TIMESTAMP) AS effective_end_timestamp,
        CASE
            WHEN event_type = 'created' THEN 'active'
            WHEN event_type = 'renewed' THEN 'active'
            WHEN event_type = 'upgraded' THEN 'active'
            WHEN event_type = 'downgraded' THEN 'active'
            WHEN event_type = 'cancelled' THEN 'churned'
            ELSE 'unknown'
        END AS period_status,
        {{ dbt_date.datediff('event_timestamp', 'COALESCE(next_event_timestamp, CURRENT_TIMESTAMP)', 'day') }} AS period_duration_days
    FROM ordered_events
),

with_mrr AS (
    SELECT
        *,
        CASE
            WHEN period_status = 'active' THEN monthly_price
            ELSE 0
        END AS period_mrr,
        CASE
            WHEN period_status = 'active' 
                 AND event_timestamp <= CURRENT_DATE 
                 AND COALESCE(next_event_timestamp, CURRENT_TIMESTAMP) > CURRENT_DATE
            THEN TRUE
            ELSE FALSE
        END AS is_currently_active
    FROM status_durations
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['subscription_id', 'event_timestamp']) }} AS subscription_event_id,
    subscription_id,
    user_id,
    event_type,
    event_category,
    period_status,
    event_timestamp AS started_at,
    effective_end_timestamp AS ended_at,
    period_duration_days AS subscription_duration_days,
    plan_id,
    monthly_price,
    period_mrr,
    is_currently_active,
    CASE
        WHEN next_event_type IS NULL AND event_type != 'cancelled' THEN 'active'
        WHEN next_event_type IS NULL AND event_type = 'cancelled' THEN 'churned'
        ELSE 'historical'
    END AS subscription_status
FROM with_mrr
ORDER BY user_id, subscription_id, started_at



## Part 5: Marts Models
# Model 1: dim_users.sql

-- models/marts/dim_users.sql
-- Purpose: User dimension with current state and derived attributes

WITH users AS (
    SELECT *
    FROM {{ ref('stg_users') }}
),

latest_subscription AS (
    SELECT
        user_id,
        MAX(CASE WHEN subscription_status = 'active' THEN 1 ELSE 0 END) AS has_active_subscription,
        MAX(plan_id) AS current_plan_id,
        MAX(monthly_price) AS current_monthly_price
    FROM {{ ref('int_subscription_events') }}
    WHERE is_currently_active = TRUE
    GROUP BY 1
),

user_activity AS (
    SELECT
        user_id,
        COUNT(DISTINCT session_id) AS lifetime_sessions,
        SUM(total_watch_seconds) AS lifetime_watch_seconds,
        COUNT(DISTINCT DATE(session_started_at)) AS active_days,
        MAX(session_started_at) AS last_activity_date,
        COUNT(DISTINCT content_id) AS unique_content_viewed,
        SUM(CASE 
            WHEN session_started_at >= DATEADD('day', -30, CURRENT_DATE) 
            THEN total_watch_seconds 
            ELSE 0 
        END) AS watch_seconds_last_30_days,
        COUNT(DISTINCT CASE 
            WHEN session_started_at >= DATEADD('day', -30, CURRENT_DATE) 
            THEN DATE(session_started_at)
        END) AS active_days_last_30_days
    FROM {{ ref('int_user_sessions') }}
    GROUP BY 1
),

churn_analysis AS (
    SELECT
        user_id,
        MIN(started_at) AS first_subscription_date,
        MAX(CASE 
            WHEN subscription_status = 'churned' 
            THEN ended_at 
        END) AS last_churn_date
    FROM {{ ref('int_subscription_events') }}
    GROUP BY 1
)

SELECT
    -- Surrogate key (already user_id is unique in dim)
    u.user_id,
    -- User attributes
    u.email,
    u.signup_date,
    u.country_code,
    u.preferred_language,
    u.marketing_opt_in,
    u.account_age_days,
    
    -- Subscription attributes
    COALESCE(ls.has_active_subscription, 0) AS has_active_subscription,
    ls.current_plan_id,
    ls.current_monthly_price,
    ca.first_subscription_date,
    ca.last_churn_date,
    
    -- Activity metrics
    COALESCE(ua.lifetime_sessions, 0) AS lifetime_sessions,
    COALESCE(ua.lifetime_watch_seconds, 0) AS lifetime_watch_seconds,
    ROUND(ua.lifetime_watch_seconds / 3600.0, 2) AS lifetime_watch_hours,
    COALESCE(ua.active_days, 0) AS lifetime_active_days,
    ua.last_activity_date,
    COALESCE(ua.unique_content_viewed, 0) AS unique_content_viewed,
    
    -- Recent activity (last 30 days)
    COALESCE(ua.watch_seconds_last_30_days, 0) AS watch_seconds_last_30_days,
    COALESCE(ua.active_days_last_30_days, 0) AS active_days_last_30_days,
    
    -- Derived flags and segments
    CASE
        WHEN ls.has_active_subscription = 1 
             AND ua.last_activity_date >= DATEADD('day', -30, CURRENT_DATE)
        THEN TRUE
        ELSE FALSE
    END AS is_active_user,
    
    CASE
        WHEN ua.last_activity_date < DATEADD('day', -90, CURRENT_DATE) THEN 'churned'
        WHEN ua.last_activity_date < DATEADD('day', -30, CURRENT_DATE) THEN 'at_risk'
        WHEN ua.watch_seconds_last_30_days >= 3600 THEN 'heavy'
        WHEN ua.watch_seconds_last_30_days >= 1200 THEN 'medium'
        WHEN ua.watch_seconds_last_30_days > 0 THEN 'light'
        ELSE 'inactive'
    END AS engagement_segment,
    
    CASE
        WHEN u.account_age_days <= 7 THEN 'new'
        WHEN u.account_age_days <= 30 THEN 'developing'
        WHEN u.account_age_days <= 90 THEN 'established'
        ELSE 'veteran'
    END AS lifecycle_stage,
    
    -- Metadata
    u._loaded_at AS last_updated_at,
    CURRENT_TIMESTAMP AS dbt_loaded_at
    
FROM users u
LEFT JOIN latest_subscription ls ON u.user_id = ls.user_id
LEFT JOIN user_activity ua ON u.user_id = ua.user_id
LEFT JOIN churn_analysis ca ON u.user_id = ca.user_id



## Model 2: dim_content.sql
-- models/marts/dim_content.sql
-- Purpose: Content dimension with show-level attributes

WITH content AS (
    SELECT *
    FROM {{ ref('stg_content') }}
),

show_aggregates AS (
    SELECT
        show_id,
        COUNT(DISTINCT content_id) AS total_episodes,
        AVG(duration_minutes) AS avg_episode_duration,
        MIN(release_date) AS show_first_release,
        MAX(release_date) AS show_last_release,
        COUNT(DISTINCT genre) AS genre_count,
        LISTAGG(DISTINCT genre, ', ') AS genres_in_show
    FROM content
    WHERE content_type = 'episode'
    GROUP BY 1
),

content_performance AS (
    SELECT
        content_id,
        SUM(total_views) AS lifetime_views,
        AVG(completion_rate) AS avg_completion_rate,
        MAX(metric_date) AS last_viewed_date
    FROM {{ ref('int_content_metrics') }}
    GROUP BY 1
)

SELECT
    -- Surrogate key
    c.content_id,
    
    -- Content attributes
    c.show_id,
    c.title,
    c.genre,
    c.genre_category,
    c.release_date,
    c.duration_minutes,
    c.season_number,
    c.episode_number,
    c.content_type,
    c.is_episode,
    c.content_length_category,
    
    -- Derived date attributes
    EXTRACT(YEAR FROM c.release_date) AS release_year,
    EXTRACT(MONTH FROM c.release_date) AS release_month,
    DATE_TRUNC('week', c.release_date) AS release_week,
    {{ dbt_date.date_spine('week', 'release_date', 'CURRENT_DATE') }} AS release_cohort,
    c.days_since_release,
    
    -- Show-level aggregates
    COALESCE(sa.total_episodes, 1) AS total_episodes_in_show,
    sa.avg_episode_duration,
    sa.show_first_release,
    sa.show_last_release,
    sa.genres_in_show,
    
    -- Performance metrics
    cp.lifetime_views,
    cp.avg_completion_rate,
    cp.last_viewed_date,
    
    -- Popularity segments
    CASE
        WHEN cp.lifetime_views >= 10000 THEN 'blockbuster'
        WHEN cp.lifetime_views >= 1000 THEN 'popular'
        WHEN cp.lifetime_views >= 100 THEN 'niche'
        ELSE 'new_or_obscure'
    END AS popularity_segment,
    
    CASE
        WHEN c.days_since_release <= 7 THEN 'new_release'
        WHEN c.days_since_release <= 30 THEN 'recent'
        WHEN c.days_since_release <= 90 THEN 'current'
        WHEN c.days_since_release <= 365 THEN 'catalog'
        ELSE 'library'
    END AS content_age_segment,
    
    -- Metadata
    c._loaded_at AS last_updated_at,
    CURRENT_TIMESTAMP AS dbt_loaded_at
    
FROM content c
LEFT JOIN show_aggregates sa ON c.show_id = sa.show_id
LEFT JOIN content_performance cp ON c.content_id = cp.content_id



## Model 3: fct_engagement.sql

-- models/marts/fct_engagement.sql
-- Purpose: Daily user engagement facts

WITH daily_sessions AS (
    SELECT
        user_id,
        DATE(session_started_at) AS engagement_date,
        COUNT(DISTINCT session_id) AS sessions,
        COUNT(DISTINCT content_id) AS content_items_viewed,
        SUM(total_watch_seconds) AS total_watch_seconds,
        SUM(plays) AS total_plays,
        AVG(session_duration_seconds) AS avg_session_duration_seconds,
        MODE() WITHIN GROUP (ORDER BY device_type) AS primary_device_type
    FROM {{ ref('int_user_sessions') }}
    GROUP BY 1, 2
),

daily_events AS (
    SELECT
        user_id,
        DATE(event_timestamp) AS event_date,
        COUNT(DISTINCT CASE WHEN event_type = 'play' THEN event_id END) AS plays,
        COUNT(DISTINCT CASE WHEN event_type = 'pause' THEN event_id END) AS pauses,
        COUNT(DISTINCT CASE WHEN event_type = 'complete' THEN event_id END) AS completions,
        COUNT(DISTINCT CASE WHEN event_type = 'seek' THEN event_id END) AS seeks
    FROM {{ ref('stg_events') }}
    GROUP BY 1, 2
),

user_dim AS (
    SELECT
        user_id,
        country_code,
        current_plan_id,
        has_active_subscription,
        engagement_segment as user_segment
    FROM {{ ref('dim_users') }}
)

SELECT
    -- Surrogate key
    {{ dbt_utils.generate_surrogate_key(['ds.engagement_date', 'ds.user_id']) }} AS engagement_id,
    
    -- Foreign keys
    ds.user_id,
    ds.engagement_date,
    
    -- Date attributes for partitioning
    EXTRACT(YEAR FROM ds.engagement_date) AS year,
    EXTRACT(MONTH FROM ds.engagement_date) AS month,
    EXTRACT(DAY FROM ds.engagement_date) AS day,
    EXTRACT(DOW FROM ds.engagement_date) AS day_of_week,
    
    -- User attributes (from dim)
    ud.country_code,
    ud.current_plan_id,
    ud.has_active_subscription,
    ud.user_segment,
    
    -- Engagement metrics
    COALESCE(ds.sessions, 0) AS sessions,
    COALESCE(ds.total_watch_seconds, 0) AS total_watch_seconds,
    ROUND(COALESCE(ds.total_watch_seconds, 0) / 60.0, 2) AS total_watch_minutes,
    COALESCE(ds.total_watch_seconds / 3600.0, 0) AS total_watch_hours,
    COALESCE(ds.content_items_viewed, 0) AS content_items_viewed,
    COALESCE(ds.total_plays, 0) AS plays,
    COALESCE(de.plays, 0) AS event_plays,  -- Different grain, can be cross-checked
    COALESCE(de.pauses, 0) AS pauses,
    COALESCE(de.completions, 0) AS completions,
    COALESCE(de.seeks, 0) AS seeks,
    ds.avg_session_duration_seconds,
    ds.primary_device_type,
    
    -- Derived engagement tiers
    CASE
        WHEN COALESCE(ds.total_watch_seconds, 0) / 60.0 > 30 THEN 'heavy'
        WHEN COALESCE(ds.total_watch_seconds, 0) / 60.0 BETWEEN 10 AND 30 THEN 'medium'
        WHEN COALESCE(ds.total_watch_seconds, 0) / 60.0 BETWEEN 1 AND 10 THEN 'light'
        WHEN COALESCE(ds.total_watch_seconds, 0) = 0 THEN 'inactive'
        ELSE 'unknown'
    END AS engagement_tier,
    
    -- Quality metrics
    CASE
        WHEN COALESCE(ds.sessions, 0) > 0 
        THEN COALESCE(de.completions, 0) / NULLIF(COALESCE(de.plays, 0), 0)
        ELSE 0
    END AS completion_rate,
    
    CASE
        WHEN COALESCE(ds.sessions, 0) > 0
        THEN COALESCE(ds.total_watch_seconds, 0) / ds.sessions
        ELSE 0
    END AS avg_watch_seconds_per_session,
    
    -- Flags
    CASE WHEN COALESCE(ds.sessions, 0) > 0 THEN TRUE ELSE FALSE END AS had_engagement,
    CASE WHEN COALESCE(de.completions, 0) > 0 THEN TRUE ELSE FALSE END AS completed_content,
    
    -- Metadata
    CURRENT_TIMESTAMP AS dbt_loaded_at
    
FROM daily_sessions ds
FULL OUTER JOIN daily_events de 
    ON ds.user_id = de.user_id AND ds.engagement_date = de.event_date
LEFT JOIN user_dim ud ON COALESCE(ds.user_id, de.user_id) = ud.user_id
WHERE COALESCE(ds.user_id, de.user_id) IS NOT NULL

Explanation: This fact table provides daily user engagement metrics by combining session-level aggregates with event-level details. It creates engagement tiers based on watch time and includes quality metrics like completion rate. The FULL OUTER JOIN ensures we capture days with events but no complete sessions


## Model 4: fct_revenue.sql
-- models/marts/fct_revenue.sql
-- Purpose: Revenue transactions

WITH subscription_events AS (
    SELECT
        subscription_id,
        user_id,
        event_type,
        event_category,
        event_timestamp,
        event_date,
        plan_id,
        monthly_price,
        subscription_status
    FROM {{ ref('stg_subscriptions') }}
),

-- Define pricing rules and adjustments
pricing_rules AS (
    SELECT
        plan_id,
        monthly_price AS base_price,
        CASE
            WHEN plan_id = 1 THEN 'Basic'
            WHEN plan_id = 2 THEN 'Standard'
            WHEN plan_id = 3 THEN 'Premium'
            WHEN plan_id = 4 THEN 'Family'
        END AS plan_name,
        CASE
            WHEN plan_id IN (1, 2) THEN 0.10  -- 10% tax for basic plans
            ELSE 0.15                         -- 15% tax for premium plans
        END AS tax_rate
    FROM (
        SELECT DISTINCT plan_id, monthly_price 
        FROM {{ ref('stg_subscriptions') }}
    )
),

-- Calculate revenue for each transaction type
revenue_calculations AS (
    SELECT
        se.subscription_id,
        se.user_id,
        se.event_type,
        se.event_category,
        se.event_timestamp,
        se.event_date,
        se.plan_id,
        se.monthly_price,
        pr.plan_name,
        pr.tax_rate,
        
        -- Calculate base amount based on event type
        CASE
            -- New subscriptions and renewals: full monthly price
            WHEN se.event_category IN ('new', 'renewal') THEN se.monthly_price
            
            -- Upgrades: price difference (can be prorated in real implementation)
            WHEN se.event_category = 'upgrade' THEN 
                se.monthly_price - LAG(se.monthly_price) OVER (
                    PARTITION BY se.subscription_id 
                    ORDER BY se.event_timestamp
                )
            
            -- Downgrades: negative price difference
            WHEN se.event_category = 'downgrade' THEN 
                se.monthly_price - LAG(se.monthly_price) OVER (
                    PARTITION BY se.subscription_id 
                    ORDER BY se.event_timestamp
                )
            
            -- Cancellations: $0 (no revenue)
            WHEN se.event_category = 'churn' THEN 0
            
            -- Refunds: negative amount (can be handled separately)
            WHEN se.event_type = 'refund' THEN -se.monthly_price
            
            ELSE 0
        END AS base_amount,
        
        -- Track previous plan for upgrade/downgrade calculations
        LAG(se.monthly_price) OVER (
            PARTITION BY se.subscription_id 
            ORDER BY se.event_timestamp
        ) AS previous_monthly_price,
        
        LAG(se.plan_id) OVER (
            PARTITION BY se.subscription_id 
            ORDER BY se.event_timestamp
        ) AS previous_plan_id

    FROM subscription_events se
    LEFT JOIN pricing_rules pr ON se.plan_id = pr.plan_id
),

final_calculations AS (
    SELECT
        *,
        -- Apply tax
        ROUND(base_amount * (1 + tax_rate), 2) AS amount_with_tax,
        
        -- Determine transaction type for reporting
        CASE
            WHEN event_category = 'new' AND base_amount > 0 THEN 'new_subscription'
            WHEN event_category = 'renewal' AND base_amount > 0 THEN 'renewal'
            WHEN event_category = 'upgrade' AND base_amount > 0 THEN 'upgrade'
            WHEN event_category = 'upgrade' AND base_amount < 0 THEN 'downgrade'  -- Actually a downgrade in price
            WHEN event_category = 'downgrade' AND base_amount < 0 THEN 'downgrade'
            WHEN event_type = 'refund' THEN 'refund'
            WHEN base_amount = 0 THEN 'no_charge'
            ELSE 'other'
        END AS transaction_type,
        
        -- Flag for adjustments
        CASE WHEN base_amount != monthly_price THEN TRUE ELSE FALSE END AS is_adjustment

    FROM revenue_calculations
)

SELECT
    -- Surrogate key
    {{ dbt_utils.generate_surrogate_key(['subscription_id', 'event_timestamp']) }} AS revenue_transaction_id,
    
    -- Foreign keys
    subscription_id,
    user_id,
    plan_id,
    
    -- Transaction details
    transaction_type,
    event_category,
    event_type,
    event_timestamp,
    event_date,
    
    -- Financial metrics
    monthly_price AS list_price,
    previous_monthly_price,
    previous_plan_id,
    base_amount AS amount,
    amount_with_tax,
    tax_rate,
    
    -- Plan info
    plan_name,
    
    -- Derived metrics
    EXTRACT(YEAR FROM event_date) AS year,
    EXTRACT(MONTH FROM event_date) AS month,
    EXTRACT(QUARTER FROM event_date) AS quarter,
    
    -- Flags
    is_adjustment,
    CASE WHEN base_amount > 0 THEN TRUE ELSE FALSE END AS is_revenue_generating,
    CASE WHEN base_amount < 0 THEN TRUE ELSE FALSE END AS is_refund_or_credit,
    
    -- Metadata
    CURRENT_TIMESTAMP AS dbt_loaded_at
    
FROM final_calculations
WHERE base_amount != 0  -- Filter out no-charge transactions
   OR event_type = 'refund'  -- But keep refunds even if amount is weird
ORDER BY event_timestamp

Explanation: This fact table models revenue transactions from subscription events. It handles different transaction types (new, renewal, upgrade, downgrade) by calculating the appropriate amount, including price differences for plan changes. It also applies tax rates and creates a clean transaction type for reporting.



## Model 5: fct_subscriptions.sql
-- models/marts/fct_subscriptions.sql
-- Purpose: Monthly subscription status with MRR

WITH subscription_history AS (
    SELECT
        subscription_id,
        user_id,
        period_status,
        started_at,
        ended_at,
        plan_id,
        monthly_price,
        period_mrr,
        is_currently_active
    FROM {{ ref('int_subscription_events') }}
),

-- Generate a series of months for each subscription
subscription_months AS (
    SELECT
        sh.subscription_id,
        sh.user_id,
        sh.plan_id,
        sh.monthly_price,
        sh.period_mrr AS original_mrr,
        sh.period_status,
        sh.started_at,
        sh.ended_at,
        -- Generate first day of each month between start and end
        DATE_TRUNC('month', sh.started_at) AS month_start,
        DATE_TRUNC('month', sh.ended_at) AS month_end,
        -- Flag if this is the first month (for proration)
        CASE 
            WHEN DATE_TRUNC('month', sh.started_at) = DATE_TRUNC('month', sh.ended_at) 
            THEN 'single_month'
            WHEN sh.started_at = DATE_TRUNC('month', sh.started_at) 
            THEN 'full_month'
            ELSE 'partial_start'
        END AS month_type
    FROM subscription_history sh
    WHERE sh.period_status = 'active'  -- Only active periods generate MRR
),

-- Calculate prorated MRR for partial months
mrr_calculation AS (
    SELECT
        *,
        -- Calculate proration factor for first/last month
        CASE
            WHEN month_type = 'full_month' THEN 1.0
            WHEN month_type = 'single_month' THEN
                -- Prorate based on days in the month
                {{ dbt_date.datediff('started_at', 'ended_at', 'day') }} * 1.0 /
                {{ dbt_date.date_part('day', 'LAST_DAY(month_start)') }}
            WHEN month_type = 'partial_start' THEN
                -- Prorate from start date to end of month
                ({{ dbt_date.date_part('day', 'LAST_DAY(month_start)') }} - 
                 {{ dbt_date.date_part('day', 'started_at') }} + 1) * 1.0 /
                {{ dbt_date.date_part('day', 'LAST_DAY(month_start)') }}
            ELSE 1.0
        END AS proration_factor,
        
        -- Generate all months in the range
        DATE_TRUNC('month', started_at) AS mrr_month
        
    FROM subscription_months
),

-- Cross join with month series to get one row per month
months_series AS (
    SELECT DISTINCT
        DATE_TRUNC('month', event_date) AS mrr_month
    FROM {{ ref('fct_revenue') }}
    UNION
    SELECT DISTINCT
        DATE_TRUNC('month', event_date) AS mrr_month
    FROM {{ ref('fct_engagement') }}
),

subscriptions_by_month AS (
    SELECT
        mc.subscription_id,
        mc.user_id,
        mc.plan_id,
        mc.monthly_price,
        mc.original_mrr,
        ms.mrr_month,
        mc.started_at,
        mc.ended_at,
        -- Calculate MRR for this month
        CASE
            WHEN ms.mrr_month >= DATE_TRUNC('month', mc.started_at) 
                 AND ms.mrr_month <= DATE_TRUNC('month', COALESCE(mc.ended_at, '2999-12-31'))
            THEN ROUND(mc.original_mrr * mc.proration_factor, 2)
            ELSE 0
        END AS mrr,
        
        -- Determine status for this month
        CASE
            WHEN ms.mrr_month < DATE_TRUNC('month', mc.started_at) THEN 'future'
            WHEN ms.mrr_month > DATE_TRUNC('month', COALESCE(mc.ended_at, CURRENT_DATE)) 
                 AND mc.ended_at IS NOT NULL THEN 'churned'
            WHEN ms.mrr_month = DATE_TRUNC('month', CURRENT_DATE) 
                 AND mc.ended_at IS NULL THEN 'active'
            WHEN ms.mrr_month <= DATE_TRUNC('month', CURRENT_DATE) 
                 AND (mc.ended_at IS NULL OR ms.mrr_month <= DATE_TRUNC('month', mc.ended_at))
            THEN 'active'
            ELSE 'inactive'
        END AS monthly_status
        
    FROM months_series ms
    CROSS JOIN mrr_calculation mc
    WHERE ms.mrr_month BETWEEN '2020-01-01' AND '2030-12-31'
),

aggregated_monthly AS (
    SELECT
        mrr_month,
        user_id,
        COUNT(DISTINCT subscription_id) AS active_subscriptions,
        SUM(mrr) AS total_mrr,
        AVG(mrr) AS avg_mrr_per_subscription,
        LISTAGG(DISTINCT plan_id::VARCHAR, ', ') AS active_plans
    FROM subscriptions_by_month
    WHERE monthly_status = 'active'
    GROUP BY 1, 2
)

SELECT
    -- Surrogate key
    {{ dbt_utils.generate_surrogate_key(['mrr_month', 'user_id']) }} AS subscription_fact_id,
    
    -- Foreign keys
    user_id,
    
    -- Time dimensions
    mrr_month AS month_date,
    EXTRACT(YEAR FROM mrr_month) AS year,
    EXTRACT(MONTH FROM mrr_month) AS month_number,
    TO_CHAR(mrr_month, 'YYYY-MM') AS year_month,
    
    -- Subscription metrics
    active_subscriptions,
    total_mrr,
    avg_mrr_per_subscription,
    active_plans,
    
    -- MRR growth calculation (using LAG)
    LAG(total_mrr) OVER (PARTITION BY user_id ORDER BY mrr_month) AS previous_month_mrr,
    total_mrr - LAG(total_mrr) OVER (PARTITION BY user_id ORDER BY mrr_month) AS mrr_change,
    CASE 
        WHEN LAG(total_mrr) OVER (PARTITION BY user_id ORDER BY mrr_month) > 0
        THEN (total_mrr - LAG(total_mrr) OVER (PARTITION BY user_id ORDER BY mrr_month)) / 
             LAG(total_mrr) OVER (PARTITION BY user_id ORDER BY mrr_month)
        ELSE NULL
    END AS mrr_growth_rate,
    
    -- Customer segments
    CASE
        WHEN total_mrr >= 50 THEN 'high_value'
        WHEN total_mrr >= 20 THEN 'medium_value'
        WHEN total_mrr > 0 THEN 'low_value'
        ELSE 'zero_value'
    END AS customer_value_segment,
    
    -- Metadata
    CURRENT_TIMESTAMP AS dbt_loaded_at
    
FROM aggregated_monthly
WHERE total_mrr > 0 OR active_subscriptions > 0  -- Only include months with activity
ORDER BY mrr_month DESC, user_id

Explanation: This fact table provides monthly subscription snapshots with MRR calculations. It handles proration for partial months, generates one row per user per month, and includes MRR growth metrics. This is essential for subscription business reporting and cohort analysis.


## Part 6: Tests and Documentation
Task 1: Schema Tests
# models/marts/_marts_models.yml

version: 2

models:
  - name: dim_users
    description: "User dimension - one row per user with current state"
    columns:
      - name: user_id
        description: "Unique identifier for each user"
        tests:
          - not_null
          - unique
          
      - name: email
        description: "User's email address (lowercase, trimmed)"
        tests:
          - not_null
          - unique
          - dbt_expectations.expect_column_values_to_match_regex:
              regex: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
              
      - name: country_code
        description: "ISO 2-letter country code"
        tests:
          - not_null
          - accepted_values:
              values: ['US', 'GB', 'CA', 'AU', 'DE', 'FR', 'JP', 'XX']
              
      - name: has_active_subscription
        description: "Flag indicating if user has an active subscription"
        tests:
          - not_null
          - accepted_values:
              values: [0, 1]
              
      - name: engagement_segment
        description: "User engagement category based on last 30 days activity"
        tests:
          - not_null
          - accepted_values:
              values: ['heavy', 'medium', 'light', 'inactive', 'at_risk', 'churned']
              
      - name: lifetime_watch_hours
        description: "Total lifetime watch hours"
        tests:
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 87600  # 10 years * 24h * 365d
              
  - name: fct_engagement
    description: "Daily engagement facts - one row per user per day"
    columns:
      - name: engagement_id
        description: "Surrogate key for the engagement record"
        tests:
          - not_null
          - unique
          
      - name: user_id
        description: "Foreign key to dim_users"
        tests:
          - not_null
          - relationships:
              to: ref('dim_users')
              field: user_id
              
      - name: engagement_date
        description: "Date of engagement"
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: '2020-01-01'
              max_value: '2030-12-31'
              
      - name: sessions
        description: "Number of sessions on this day"
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 100  # Reasonable max sessions per day
              
      - name: total_watch_minutes
        description: "Total minutes watched on this day"
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 1440  # Max minutes in a day
              
      - name: engagement_tier
        description: "Engagement level based on watch time"
        tests:
          - not_null
          - accepted_values:
              values: ['heavy', 'medium', 'light', 'inactive']
              
      - name: unique_key_combination
        description: "Ensure no duplicate user/date combinations"
        tests:
          - dbt_utils.unique_combination_of_columns:
              combination_of_columns:
                - user_id
                - engagement_date
                
  - name: fct_revenue
    description: "Revenue transactions"
    columns:
      - name: revenue_transaction_id
        description: "Surrogate key for revenue transaction"
        tests:
          - not_null
          - unique
          
      - name: subscription_id
        description: "Subscription identifier"
        tests:
          - not_null
          
      - name: user_id
        description: "Foreign key to dim_users"
        tests:
          - not_null
          - relationships:
              to: ref('dim_users')
              field: user_id
              
      - name: amount
        description: "Transaction amount (negative for refunds/credits)"
        tests:
          - not_null
          
      - name: transaction_type
        description: "Type of revenue transaction"
        tests:
          - not_null
          - accepted_values:
              values: ['new_subscription', 'renewal', 'upgrade', 'downgrade', 'refund']
              
      - name: dbt_expectations.expect_column_values_to_be_between
        description: "Amount should be within reasonable range"
        tests:
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: -500  # Max refund
              max_value: 500    # Max charge



## Task 2: Custom Tests
-- tests/assert_no_negative_revenue.sql
-- Revenue amounts should never be negative (except refunds)

WITH negative_non_refund AS (
    SELECT
        revenue_transaction_id,
        transaction_type,
        amount,
        event_date
    FROM {{ ref('fct_revenue') }}
    WHERE amount < 0 
      AND transaction_type != 'refund'
      AND transaction_type != 'downgrade'  -- Downgrades can be negative (price difference)
)

SELECT * FROM negative_non_refund

-- This test will fail if any rows are returned

-- tests/assert_mrr_consistency.sql
-- Total MRR should not change by more than 10% month-over-month

WITH monthly_mrr AS (
    SELECT
        year_month,
        SUM(total_mrr) AS total_mrr
    FROM {{ ref('fct_subscriptions') }}
    GROUP BY 1
),

mrr_with_lag AS (
    SELECT
        year_month,
        total_mrr,
        LAG(total_mrr) OVER (ORDER BY year_month) AS prev_month_mrr,
        CASE 
            WHEN LAG(total_mrr) OVER (ORDER BY year_month) > 0
            THEN ABS(total_mrr - LAG(total_mrr) OVER (ORDER BY year_month)) / 
                 LAG(total_mrr) OVER (ORDER BY year_month)
            ELSE 0
        END AS pct_change
    FROM monthly_mrr
    WHERE year_month >= '2023-01-01'  -- Only check recent months
)

SELECT
    year_month,
    total_mrr,
    prev_month_mrr,
    ROUND(pct_change * 100, 2) AS pct_change_percentage
FROM mrr_with_lag
WHERE pct_change > 0.10  -- More than 10% change
  AND prev_month_mrr IS NOT NULL

-- This test will fail if any month has >10% MRR change


-- tests/assert_active_users_have_engagement.sql
-- Users flagged as active should have engagement in the last 30 days

WITH active_users AS (
    SELECT
        user_id,
        is_active_user,
        last_activity_date
    FROM {{ ref('dim_users') }}
    WHERE is_active_user = TRUE
),

recent_engagement AS (
    SELECT DISTINCT
        user_id
    FROM {{ ref('fct_engagement') }}
    WHERE engagement_date >= DATEADD('day', -30, CURRENT_DATE)
)

SELECT
    au.user_id,
    au.last_activity_date,
    CURRENT_DATE AS today,
    DATEADD('day', -30, CURRENT_DATE) AS thirty_days_ago
FROM active_users au
LEFT JOIN recent_engagement re ON au.user_id = re.user_id
WHERE re.user_id IS NULL
  AND au.last_activity_date < DATEADD('day', -30, CURRENT_DATE)

-- This test will fail if any user flagged as active has no engagement in last 30 days




## Task 3: Model Descriptions
-- models/marts/dim_users.sql
{{ config(
    materialized='table',
    description='User dimension table containing demographic information, subscription status, and derived engagement segments. One row per user with current state.'
) }}

/*
Description: User dimension with current state and derived attributes
Business Definition: Core user entity for all analytics. Used to segment users by engagement, value, and lifecycle stage.
Update Frequency: Daily

Key Columns:
- user_id: Unique identifier (PK)
- email: User email (PII, masked in non-prod)
- country_code: ISO 2-letter country for geo-analysis
- has_active_subscription: Critical for revenue segmentation
- engagement_segment: Heavy/Medium/Light/Inactive based on 30-day watch time
- lifecycle_stage: New/Developing/Established/Veteran based on account age

Known Limitations:
- engagement_segment based only on last 30 days, doesn't consider historical patterns
- country_code may be 'XX' for unknown/unrecognized countries
- lifetime metrics stop updating after 90 days of inactivity (data retention policy)

Usage Examples:
- Active user counts by country: SELECT country_code, COUNT(*) FROM dim_users WHERE is_active_user = TRUE GROUP BY 1
- Engagement distribution: SELECT engagement_segment, COUNT(*) FROM dim_users GROUP BY 1
*/


-- models/marts/fct_engagement.sql
{{ config(
    materialized='table',
    description='Daily user engagement fact table. One row per user per day with watch time, session counts, and derived engagement tiers.'
) }}

/*
Description: Daily user engagement facts
Business Definition: Tracks user activity at daily grain to understand engagement patterns, retention, and content consumption.
Update Frequency: Daily, with 1-hour latency

Key Columns:
- engagement_id: Surrogate key
- user_id: Foreign key to dim_users
- engagement_date: Calendar date
- total_watch_minutes: Primary engagement metric
- sessions: Number of distinct viewing sessions
- engagement_tier: Heavy (>30min), Medium (10-30min), Light (<10min), Inactive (0min)
- completion_rate: % of plays that resulted in completion

Known Limitations:
- Sessions defined by 30-minute inactivity gap - may not perfectly match true user sessions
- Watch time capped at content duration (technical limitation)
- Data for current day is partial until EOD processing

Usage Examples:
- DAU/WAU/MAU calculations: SELECT COUNT(DISTINCT user_id) FROM fct_engagement WHERE engagement_date = CURRENT_DATE
- Engagement trends: SELECT engagement_date, AVG(total_watch_minutes) FROM fct_engagement GROUP BY 1
- Cohort retention: Select users by signup cohort and track daily engagement
*/


-- models/marts/fct_subscriptions.sql
{{ config(
    materialized='table',
    description='Monthly subscription snapshot fact table. One row per user per month with MRR and subscription status.'
) }}

/*
Description: Monthly subscription status with MRR
Business Definition: Core financial table for subscription analytics. Tracks active subscriptions, MRR, and customer value over time.
Update Frequency: Monthly, with daily incremental updates

Key Columns:
- subscription_fact_id: Surrogate key
- user_id: Foreign key to dim_users
- month_date: First day of the month (YYYY-MM-01)
- active_subscriptions: Count of active subscriptions for the user
- total_mrr: Monthly Recurring Revenue in USD
- mrr_growth_rate: Month-over-month MRR change percentage
- customer_value_segment: High/Medium/Low based on MRR

Known Limitations:
- Prorated MRR calculations use simple day-count method, not 30/360
- Does not include one-time charges or credits (see fct_revenue)
- Future months projected based on current subscriptions (assumes renewal)

Usage Examples:
- MRR by cohort: SELECT signup_cohort, SUM(total_mrr) FROM fct_subscriptions s JOIN dim_users u ON s.user_id = u.user_id GROUP BY 1
- Churn rate: Calculate % of users with churned status month-over-month
- LTV analysis: Track cumulative MRR by user cohort over time
*/


## Bonus Challenge Solutions
Snapshots: SCD Type 2 for Subscriptions

-- snapshots/snapshot_subscriptions.sql
-- Track historical changes to subscriptions with SCD Type 2

{% snapshot snapshot_subscriptions %}

{{
    config(
        target_schema='snapshots',
        unique_key='subscription_id',
        strategy='timestamp',
        updated_at='event_timestamp',
        invalidate_hard_deletes=True,
        snapshot_meta_column_names={
            'dbt_valid_from': 'valid_from',
            'dbt_valid_to': 'valid_to',
            'dbt_scd_id': 'scd_id',
            'dbt_updated_at': 'updated_at'
        }
    )
}}

SELECT
    subscription_id,
    user_id,
    event_type,
    event_category,
    subscription_status,
    event_timestamp,
    event_date,
    plan_id,
    monthly_price,
    _loaded_at
FROM {{ ref('stg_subscriptions') }}

{% endsnapshot %}

Explanation: This snapshot tracks all changes to subscription attributes over time using timestamp strategy. When a subscription's event_timestamp changes, it creates a new record while preserving the old one with valid_from/valid_to dates. This enables point-in-time analysis of subscription states.


## Macros: Reusable Deduplication Pattern for staging
-- macros/deduplicate.sql
-- Reusable macro for common deduplication pattern

{% macro deduplicate(
    relation,
    partition_by,
    order_by,
    filter_condition=none
) %}

WITH source AS (
    SELECT *
    FROM {{ relation }}
    {% if filter_condition %}
    WHERE {{ filter_condition }}
    {% endif %}
),

deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ partition_by }}
            ORDER BY {{ order_by }}
        ) AS dedupe_rn
    FROM source
)

SELECT *
FROM deduped
WHERE dedupe_rn = 1

{% endmacro %}


-- macros/generate_surrogate_key.sql
-- Enhanced surrogate key generation with null handling

{% macro generate_surrogate_key(fields) %}

{{ dbt_utils.generate_surrogate_key(fields) }}

{% endmacro %}


-- macros/calculate_prorated_mrr.sql
-- Calculate prorated MRR for partial months

{% macro calculate_prorated_mrr(
    start_date,
    end_date,
    monthly_amount,
    month_date
) %}

CASE
    -- Full month
    WHEN DATE_TRUNC('month', {{ start_date }}) = {{ month_date }}
         AND ({{ end_date }} IS NULL OR {{ month_date }} < DATE_TRUNC('month', {{ end_date }}))
    THEN {{ monthly_amount }}
    
    -- Partial start month
    WHEN DATE_TRUNC('month', {{ start_date }}) = {{ month_date }}
    THEN {{ monthly_amount }} * (
        (DATE_PART('day', LAST_DAY({{ month_date }})) - 
         DATE_PART('day', {{ start_date }}) + 1)::FLOAT /
        DATE_PART('day', LAST_DAY({{ month_date }}))::FLOAT
    )
    
    -- Partial end month
    WHEN {{ end_date }} IS NOT NULL 
         AND DATE_TRUNC('month', {{ end_date }}) = {{ month_date }}
    THEN {{ monthly_amount }} * (
        DATE_PART('day', {{ end_date }})::FLOAT /
        DATE_PART('day', LAST_DAY({{ month_date }}))::FLOAT
    )
    
    -- No match
    ELSE 0
END

{% endmacro %}


-- macros/date_spine.sql
-- Generate date spine for missing dates

{% macro date_spine(
    datepart,
    start_date,
    end_date
) %}

{{ dbt_date.date_spine(
    datepart=datepart,
    start_date=start_date,
    end_date=end_date
) }}

{% endmacro %}


-- macros/percent_change.sql
-- Calculate percent change safely

{% macro percent_change(
    current_value,
    previous_value
) %}

CASE 
    WHEN {{ previous_value }} IS NULL OR {{ previous_value }} = 0 THEN NULL
    ELSE ({{ current_value }} - {{ previous_value }}) / NULLIF({{ previous_value }}, 0)
END

{% endmacro %}


-- Example usage in staging model:
/*
{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'raw_events') }}
),

{{ deduplicate(
    relation='source',
    partition_by='event_id',
    order_by='_loaded_at DESC',
    filter_condition='event_id IS NOT NULL'
) }}
*/


Explanation: These macros provide reusable patterns:

deduplicate: Generic deduplication using ROW_NUMBER()

generate_surrogate_key: Wrapper for dbt_utils surrogate key with enhanced null handling

calculate_prorated_mrr: Complex proration logic for subscription billing

date_spine: Generate continuous date ranges for time series

percent_change: Safe percent change calculation with null handling


## Exposures: Tableau Executive Dashboard
# models/exposures.yml

version: 2

exposures:
  - name: executive_dashboard
    label: Executive KPI Dashboard
    type: dashboard
    maturity: high
    url: https://tableau.streampulse.com/#/site/Executive/views/ExecutiveDashboard
    description: >
      Executive dashboard showing real-time business performance metrics including
      revenue, user growth, engagement, and content performance. Used daily by
      C-level executives for strategic decisions.
    
    depends_on:
      - ref('fct_revenue')
      - ref('fct_subscriptions')
      - ref('fct_engagement')
      - ref('dim_users')
      - ref('dim_content')
      - ref('int_content_metrics')
    
    owner:
      name: Sarah Chen
      email: sarah.chen@streampulse.com
      department: Data Analytics
    
    freshness:
      warn_after: {count: 24, period: hour}
      error_after: {count: 48, period: hour}
    
    tags: ['executive', 'dashboard', 'critical']
    
    metrics:
      - mrr
      - daily_active_users
      - average_watch_time
      - subscriber_growth_rate
      - content_completion_rate
    
    filters:
      - field: engagement_date
        description: "Last 90 days of data only for performance"
    
    meta:
      tableau_workbook: "Executive KPI Dashboard.twb"
      tableau_datasource: "StreamPulse Executive DS"
      refresh_schedule: "Every 4 hours"
      sla_minutes: 15

  - name: content_performance_dashboard
    label: Content Analytics Dashboard
    type: dashboard
    maturity: medium
    url: https://tableau.streampulse.com/#/site/Analytics/views/ContentPerformance
    description: >
      Content team dashboard tracking performance of movies and shows.
      Used for content acquisition and renewal decisions.
    
    depends_on:
      - ref('dim_content')
      - ref('int_content_metrics')
      - ref('stg_api_data')
      - ref('fct_engagement')
    
    owner:
      name: Marcus Rodriguez
      email: marcus.rodriguez@streampulse.com
      department: Content Strategy
    
    tags: ['content', 'analytics', 'medium']
    
    metrics:
      - content_views
      - completion_rate
      - social_engagement_score


Explanation: Exposures define the downstream usage of dbt models. This configuration:

Links dbt models to Tableau dashboards

Establishes ownership and SLAs

Defines freshness requirements for critical dashboards

Creates dependency tracking for impact analysis

Helps identify critical data assets


## Metrics: Business KPIs
# models/metrics/metrics.yml

version: 2

metrics:
  - name: mrr
    label: Monthly Recurring Revenue
    model: ref('fct_subscriptions')
    description: "Total Monthly Recurring Revenue from active subscriptions"
    
    type: sum
    sql: total_mrr
    
    timestamp: month_date
    time_grains: [day, week, month, quarter, year]
    
    dimensions:
      - plan_id
      - customer_value_segment
      - country_code
      - signup_cohort
    
    filters:
      - field: monthly_status
        operator: '='
        value: "'active'"
    
    meta:
      benchmark: 0.15  # Target 15% YoY growth
      currency: USD
    
    config:
      treat_null_values_as_zero: true

  - name: daily_active_users
    label: Daily Active Users (DAU)
    model: ref('fct_engagement')
    description: "Number of unique users who watched any content on a given day"
    
    type: count_distinct
    sql: user_id
    
    timestamp: engagement_date
    time_grains: [day, week, month, quarter, year]
    
    dimensions:
      - country_code
      - current_plan_id
      - has_active_subscription
      - engagement_tier
    
    filters:
      - field: total_watch_minutes
        operator: '>'
        value: 0
    
    meta:
      benchmark: 5000000  # Target 5M DAU
      l7_avg_moving: true

  - name: average_watch_time
    label: Average Daily Watch Time (minutes)
    model: ref('fct_engagement')
    description: "Average minutes watched per active user per day"
    
    type: average
    sql: total_watch_minutes
    
    timestamp: engagement_date
    time_grains: [day, week, month, quarter, year]
    
    dimensions:
      - country_code
      - current_plan_id
      - engagement_tier
      - user_segment
    
    filters:
      - field: total_watch_minutes
        operator: '>'
        value: 0
    
    meta:
      benchmark: 45  # Target 45 minutes per user per day
      exclude_outliers: true

  - name: subscriber_growth_rate
    label: Subscriber Growth Rate (%)
    model: ref('fct_subscriptions')
    description: "Month-over-month growth rate of active subscribers"
    
    type: derived
    expression: "{{ mrr_growth_rate }}"  # References another metric
    sql: mrr_growth_rate
    
    timestamp: month_date
    time_grains: [month, quarter, year]
    
    meta:
      benchmark: 0.05  # Target 5% monthly growth
      format: percentage

  - name: content_completion_rate
    label: Content Completion Rate (%)
    model: ref('int_content_metrics')
    description: "Percentage of content views that result in completion"
    
    type: average
    sql: completion_rate
    
    timestamp: metric_date
    time_grains: [day, week, month, quarter, year]
    
    dimensions:
      - genre
      - content_type
      - content_length_category
      - popularity_segment
    
    meta:
      benchmark: 0.65  # Target 65% completion rate
      format: percentage

  - name: customer_lifetime_value
    label: Customer Lifetime Value (LTV)
    model: ref('dim_users')
    description: "Average revenue per user over entire lifetime"
    
    type: derived
    sql: "lifetime_watch_hours * 0.15"  # Simplified LTV calculation
    
    timestamp: signup_date
    time_grains: [month, quarter, year]
    
    dimensions:
      - country_code
      - signup_cohort
      - lifecycle_stage
    
    meta:
      benchmark: 250  # Target $250 LTV
      calculation_method: "Simplified: watch hours * $0.15"

  - name: social_engagement_score
    label: Social Media Engagement Score
    model: ref('stg_api_data')
    description: "Composite score of social media engagement for content"
    
    type: derived
    sql: "(likes + shares * 2 + comments * 3) / NULLIF(api_views, 0)"
    
    timestamp: metric_date
    time_grains: [day, week, month]
    
    dimensions:
      - api_name
      - content_id
    
    meta:
      benchmark: 0.25  # Target engagement score
      weight_breakdown: "Likes:1, Shares:2, Comments:3"





