function ConvertTo-TaxFile($cfg,$file,$FreightItemsG){
    ConvertTo-TaxFile_Private $FreightItemsG | Set-Content $file
}
function ConvertTo-TaxFile_Private($FreightItemsG){
    if($FreightItemsG.count -eq 0){
        return ""
    }

    $now = Get-Date # now, the filing date
    $apd = [DateTime]$FreightItemsG[0].Shipped #any period date
    $fpd = [DateTime]::New($apd.Year,$apd.Month,1) # first period date
    $lpd = $fpd.AddMonths(1).AddSeconds(-1) #last period date

    #head
    "ISA~03~xx~00~          ~32~xx      ~01~xx     ~{0:yyMMdd}~{0:HHmm}~|~00403~0{0:yyyyMMdd}~0~P~^\" -f $now
    "GS~TF~xx~xx~{0:yyyyMMdd}~{0:HHmmss}~{0:yyyyMMdd}~X~004030\" -f $now
    "ST~813~{0:yyyyMMdd}~1.0\" -f $fpd
    "BTI~T6~xx~xx~xx~{0:yyyyMMdd}~xx~xx~xx~~~~~00\" -f $now #if amendment, replace ~00\ with ~~6S
    "DTM~194~{0:yyyyMMdd}\" -f $lpd
    "N1~TP~XXXX.\"
    "N2~XXXX\"
    "N3~XXXX\"
    "N4~xx~xx~xx~xx\"
    "PER~CN~some name~TE~somenumber~FX~somenumber~EM~someemail\"
    "PER~EA~some name~TE~somenumber~FX~somenumber~EM~someemail\"
    "TFS~T2~CCR~xx~xx\"
    [int] $i = 11

    #key holder so we only add one set of TFS/N1/N4 records per key combo
    $keys = [System.Collections.Generic.HashSet[string]]::new()

    #body
    foreach($f in $FreightItemsG){
        if($keys.Add(($f."shipper.tcn",$f."consignor.tax_id",$f."consignee.tax_id",$f."cmd_code" -Join ","))){
            "TFS~T3~14~PG~$($f."cmd_code")~94~J \"
            "N1~OT~~TC~$($f."shipper.tcn")\"
            "N1~SE~$($f."supplier.name")~24~$($f."supplier.tax_id")\"
            "N1~CI~$($f."consignor.name")~24~$($f."consignor.tax_id")\"
            "N1~CA~Florida Rock and Tank Lines, INC.~24~593024457\"
            "N1~BY~$($f."consignee.name")~24~$($f."consignee.tax_id")\"
            "N1~ST~$($f."consignee.state")\"
            "N4~$($f."consignee.city")~$($f."consignee.state")~$($f."consignee.zip")\"
            $i+=8
        }
        "FGS~D~BM~$( $f."bol")\"
        "DTM~095~{0:yyyyMMdd}\" -f ([DateTime]($f."shipped"))
        "TIA~5005~~~$($f."net")~GA\"
        $i+=3
    }

    #tail
    "SE~$i~{0:yyyyMMdd}\" -f $fpd
    "GE~1~{0:yyyyMMdd}\" -f $now
    "IEA~1~0{0:yyyyMMdd}\" -f $now
}
Export-ModuleMember -Function ConvertTo-TaxFile