flowchart TD
    nf["Consideration"] --> nc["OrderCombiner"]
    nc --> ng["OrderFulfiller"] & nk["FulfillmentApplier"]
    ng --> nu["BasicOrderFulfiller"] & n0["CriteriaResolution"] & n5["AmountDeriver"]
    nu --> n7["OrderValidator"]
    n7 --> n3["Executor"] & ni["ZoneInteraction"]
    n3 --> n9["Verifiers"] & nw["TokenTransferrer"]
    n9 --> n4["Assertions"] & nb["SignatureVerification"]
    n4 --> ne["GettersAndDerivers"] & nr["CounterManager"] & nl["TokenTransferrerErrors"]
    ne --> nv["ConsiderationBase"]
    nv --> nq["ConsiderationDecoder"] & np["ConsiderationEncoder"] & n8["ConsiderationEventsAndErrors"]
    nr --> nt["ConsiderationEventsAndErrors"] & n2["ReentrancyGuard"]
    n2 --> nj["ReentrancyErrors"] & n6["LowLevelHelpers"]
    nw --> nz["TokenTransferrerErrors"]
    ni --> nm["ConsiderationEncoder"] & nn["ZoneInteractionErrors"] & na["LowLevelHelpers"]
    n0 --> nx["CriteriaResolutionErrors"]
    n5 --> nd["AmountDerivationErrors"]
    nk --> ny["FulfillmentApplicationErrors"]

