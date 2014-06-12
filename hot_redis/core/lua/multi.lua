
function rank_lists_by_length()
    local ranker_key = "__tmp__.hot_redis.rank_lists_by_length"
    for _, key in ipairs(KEYS) do
        redis.call('ZADD',
            ranker_key,
            redis.call('LLEN', key),
            key)
    end
    local result = redis.call('ZREVRANGE', ranker_key, ARGV[1], ARGV[2],
        'WITHSCORES')
    redis.call('DEL', ranker_key)
    return result
end

function rank_sets_by_cardinality()
    local ranker_key = "__tmp__.hot_redis.rank_sets_by_cardinality"
    for _, key in ipairs(KEYS) do
        redis.call('ZADD',
            ranker_key,
            redis.call('SCARD', key),
            key)
    end
    local result = redis.call('ZREVRANGE', ranker_key, ARGV[1], ARGV[2],
        'WITHSCORES')
    redis.call('DEL', ranker_key)
    return result
end

function rank_zsets_by_cardinality()
    local ranker_key = "__tmp__.hot_redis.rank_zsets_by_cardinality"
    for _, key in ipairs(KEYS) do
        redis.call('ZADD',
            ranker_key,
            redis.call('ZCARD', key),
            key)
    end
    local result = redis.call('ZREVRANGE', ranker_key, ARGV[1], ARGV[2],
        'WITHSCORES')
    redis.call('DEL', ranker_key)
    return result
end

function rank_by_sum_of_decaying_score()
    local min, max, from, halflife, cache_timeout = unpack(ARGV)
    from = tonumber(from)
    halflife = tonumber(halflife)
    local ranker_key = "__tmp__.hot_redis.rank_by_sum_of_decaying_score"
    for _, key in ipairs(KEYS) do
        local score_cache_key = key .. ':sum_of_decaying_scores:' .. halflife
        local score = redis.call('GET', score_cache_key)
        if not score then
            score = 0
            local values = redis.call('ZRANGE', key, 0, -1, 'WITHSCORES')
            for index, val in ipairs(values) do
                if index % 2 == 0 then
                    score = score + math.pow(0.5,
                        ((from - val) / halflife))
                end
            end
            if cache_timeout ~= '0' then
                redis.call('SET', score_cache_key, score, 'EX', cache_timeout)
            end
        end
        redis.call('ZADD', ranker_key, score, key)
    end
    local result = redis.call('ZREVRANGE', ranker_key, min, max, 'WITHSCORES')
    redis.call('DEL', ranker_key)
    return result
end

function rank_by_top_key_if_equal()
    local min, max, required_key_value = unpack(ARGV)
    local ranker_key = "__tmp__.hot_redis.rank_by_top_key_if_equal"
    for _, key in ipairs(KEYS) do
        local top_elements = redis.call('ZREVRANGE', key, 0, 0, 'WITHSCORES')
        if top_elements then
            local val, score = unpack(top_elements)
            if val == required_key_value then
                redis.call('ZADD', ranker_key, score, key)
            end
        end
    end
    local result = redis.call('ZREVRANGE', ranker_key, min, max, 'WITHSCORES')
    redis.call('DEL', ranker_key)
    return result
end

function multi_zset_fixed_width_histogram()
    local from, to, bucket_width = unpack(ARGV)
    local histogram = {}
    for _, key in ipairs(KEYS) do
        local scores = redis.call('ZRANGEBYSCORE', key, from, to,
            'WITHSCORES')
        for index, val in ipairs(scores) do
            if index % 2 == 0 then
                local bucket_index = val - val % bucket_width
                if histogram[bucket_index] == nil then
                    histogram[bucket_index] = 1
                else
                    histogram[bucket_index] = histogram[bucket_index] + 1
                end
            end
        end
    end
    return histogram
end
