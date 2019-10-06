"""
picks a subgroup and nudge magnitude, if it exceeds a threshold.
This function is somewhat generic...
"""
function pick_subgroup_and_magnitude(train_subpop_table,
    train, y_train, train_vectors, test, test_vectors, TOL, verbose)

    # prepare the scanned column
    train_subpop_table[:, :scanned] = fill(false, nrow(train_subpop_table))

    vect_index = -1
    nudge_magnitude = 0
    max_res = 0

    while true  # loop until you find something
        # get candidates and choose among them
        candidates = findall(.!train_subpop_table[:scanned])
        if verbose==1
            println("now considering $(length(candidates)) candidates")
            if verbose==2
                println("candidate indices are $candidates")
            end
        end
        if candidates == []  # nothing left to choose
            return -1, 0, 0
        end

        vect_index = rand(candidates)

        # get the boolean vectors and subset
        train_boolean_vector = train_vectors[vect_index]
        sub_train = train[train_boolean_vector]
        sub_labels = y_train[train_boolean_vector]

        test_boolean_vector = test_vectors[vect_index]
        sub_test = test[test_boolean_vector]

        # get the magnitude
        max_res = 0 # the best improvement
        nudge_magnitude = 0 # how much to nudge for it

        nudge_magnitude = mean(sub_labels) - mean(sub_train)
        max_res = abs(nudge_magnitude)

        # is the absolute difference over TOL?
        if max_res <= TOL
            train_subpop_table[vect_index, :scanned] = true
            if verbose==1
                print_with_color(:red, "vect_index $vect_index couldn't find what to correct, max_improvement was $max_res\n")
            end
        else # passed the test, so return the results
            if verbose==1
                print_with_color(:green, "vect_index $vect_index moving by $nudge_magnitude for improvement of $max_res\n")
            end
            train_subpop_table[:, :scanned] = fill(false, nrow(train_subpop_table))
            break
        end
    end

    return vect_index, nudge_magnitude, max_res
end

"nudges the sets from a given boolean vector in a given magnitude"
function nudge_global(train, test, train_vectors, test_vectors,
    magnitude, vect_index, verbose)

    # first, announce your intentions
    if verbose==2
        println("Nudging the subset from row $vect_index by magnitude $magnitude")
    end

    # get the boolean vectors
    train_vect = train_vectors[vect_index]
    test_vect = test_vectors[vect_index]

    # nudge
    train[train_vect] .+= magnitude
    test[test_vect] .+= magnitude

    # correct anyone who went under 0
    train[train .<= 0] .= 1e-8
    test[test .<= 0] .= 1e-8

    # or over 1
    train[train .>= 1] .= 1-(1e-8)
    test[test .>= 1] .= 1-(1e-8)

    return train, test
end

"""
This function implements a variant of the algorithm described in
    Hebert-Johnson et al. (2017)
The algorithm aims to improve subpopulation calibration by repeatedly "nudging"
predictions in each subpopulation towards the observed outcome mean.


# Arguments
- `preds_train_recaled::Any`: a vector of predictions on the training set.
- `preds_test_recaled::Any`: a vector of predictions on the test set.
- `train_subpop_table::Any`: a dataframe containing the training population.
- `y_train::Any`: a vector of outcomes on the training set.
- `y_test::Any`: a vector of outcomes on the test set.
- `train_vectors::Any`: a vector of logical vectors, each detailing membership
    of the training population in the subpopulation at that index.
- `test_vectors::Any`: a vector of logical vectors, each detailing membership
    of the test population in the subpopulation at that index.
- `verbose::Any`: an integer in the set {0,1,2} detailing the amount of feedback
    to print to screen.
- `TOL::Any`: the allowed difference between the mean of the prediction and
    the mean of the outcomes in any subpopulation
"""
function recalibrate(preds_train_recaled, preds_test_recaled,
    train_subpop_table, y_train, y_test, train_vectors, test_vectors,
    verbose=false, TOL=0.001)

    train, test = replicate_datasets(preds_train_recaled, preds_test_recaled)

    nudge_history = Dict("subpop" => Int64[], "magnitude" => Float64[], "improvement" => Float64[])

    index = 1

    while true
        if verbose==1
            println("index is $index")
        end

        subpop_index, magnitude, improvement = pick_subgroup_and_magnitude(
            train_subpop_table, train, y_train, train_vectors,
            test, test_vectors, TOL, verbose)
        if subpop_index == -1  # couldn't find anything to nudge
            break
        end

        train, test = nudge_global(train, test,
            train_vectors, test_vectors,
            magnitude, subpop_index, verbose)

        append!(nudge_history["subpop"], subpop_index)
        append!(nudge_history["magnitude"], magnitude)
        append!(nudge_history["improvement"], improvement)

        index += 1

    end

    nudge_history_df = DataFrame(nudge_history)
    nudge_history_df = nudge_history_df[[:subpop, :magnitude, :improvement]]

    return train, test, nudge_history_df
end
