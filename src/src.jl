
using DataFrames
using LinearAlgebra
using FreqTables
using StatsBase


Base.@kwdef mutable struct kNN_classifier
    k::Int64
    p::Float64
    data::DataFrame
    labels::DataFrame
    classify::Function
    kNN_classifier(k, p, data, labels) = new(k, p, data, labels, 
        (x::DataFrameRow) -> begin
            ftd = Dict(
                freqtable(labels[map(
                    s::DataFrameRow -> norm(collect(s) - collect(x), p), eachrow(data)
                ) .<= kDistance(data, x, k, p), 
                :][!, 1]
            ))
            argmax(ftd)
        end
    )
end

function kDistance(data::DataFrame, x::DataFrameRow, k::Int64, p::Float64)
    sort(map(s::DataFrameRow -> norm(collect(s) - collect(x), p), eachrow(data)))[k]
end

function dataframe_classify(f::T, x::DataFrame) where T<:Function
    DataFrame(class=map(x_ -> f(x_), eachrow(x)))
end

"""
    acc(f, x, y)

Get accuracy of the kNN classifier.

f<:Function - kNN classifier.classify function.
x::DataFrame - input data.
y::DataFrame - labels.

"""
function acc(f::T, x::DataFrame, y::DataFrame) where T<:Function 
    mean(Int.(dataframe_classify(f, x) .== y).class)
end

"""
    leave_one_out_kNN(dataset, data_cols, label_cols, k, p)

Get accuracy of the kNN classifier by the leave-one-out method.

dataset::DataFrame - frame of the dataset.
data_cols::UnitRange{Int64} - input data columns range.
labels_cols::Int64 - labels column index.
"""
function leave_one_out_kNN(dataset::DataFrame, data_cols::UnitRange{Int64}, 
        label_col::Int64, k::Int64, p::Float64)
    results::Vector{Bool} = []
    for i::Int64=1:size(dataset)[1]
        tmp_d::DataFrame = deepcopy(dataset)
        leaved::DataFrame = DataFrame(tmp_d[i, :])
        deleteat!(tmp_d, i)
        classifier = kNN_classifier(k, p, tmp_d[:, data_cols], DataFrame(class=tmp_d[:, label_col]))
        append!(results, [classifier.classify(leaved[1, data_cols]) == leaved[1, label_col]])
    end
    mean(results)
end

leave_one_out_kNN(dataset::DataFrame, data_cols::UnitRange{Int64}, 
    label_col::Int64, k::Int64, p::Int64) = leave_one_out(dataset, data_cols, label_col, k, Float64(p))

"""
    contingency_table(f, x, y)

Get contingency table of the kNN classifier.

f<:Function - kNN classifier.classify function.
x::DataFrame - input data.
y::DataFrame - labels.

"""
function contingency_table(f::T, x::DataFrame, y::DataFrame) where T<:Function 
    labels_mapping::Dict{String, Int64} = Dict(String.(unique(y.class)) .=> 1:length(unique(y.class)))
    contab::Matrix{Float64} = zeros(length(labels_mapping), length(labels_mapping))
    ŷ::Vector{String} = String.(dataframe_classify(f, x).class)
    map(xy -> contab[
            labels_mapping[xy[1]], labels_mapping[xy[2]]
        ] += 1, zip(ŷ, String.(y.class)))
    return contab, labels_mapping
end
