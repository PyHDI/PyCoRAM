proc platgen_update  {mhsinst} {
    generate_corelevel_ucf $mhsinst
    generate_corelevel_xdc $mhsinst
}

proc generate_corelevel_ucf {mhsinst} {
    set filePath [xget_ncf_dir $mhsinst]
    file mkdir $filePath

    # specify file name
    set    instname   [xget_hw_parameter_value $mhsinst "INSTANCE"]
    set    name_lower [string   tolower   $instname]

    set    fileName   $name_lower
    append fileName   "_wrapper.ucf"
    append filePath   $fileName

    # Open a file for writing
    set outputFile [open $filePath "w"]

    ## Create CDC TIG constraints
    puts $outputFile "INST \"${instname}/*cdc_from*\" TNM = FFS \"TNM_${instname}_cdc_from\";"
    #puts $outputFile "INST \"${instname}/*cdc_to*\" TNM = FFS \"TNM_${instname}_cdc_to\";"
    #puts $outputFile "TIMESPEC TS_${instname}_cdc_from_2_cdc_to = FROM \"TNM_${instname}_cdc_from\" TO \"TNM_${instname}_cdc_to\" TIG;"
    puts $outputFile "TIMESPEC TS_${instname}_cdc_from_2_cdc_to = FROM \"TNM_${instname}_cdc_from\" TIG;"

    puts $outputFile "#"
    puts $outputFile "#"
    puts $outputFile "\n"       

    # Close the file
    close $outputFile
}

proc generate_corelevel_xdc {mhsinst} {
    set filePath [xget_ncf_dir $mhsinst]
    file mkdir $filePath

    # specify file name
    set    instname   [xget_hw_parameter_value $mhsinst "INSTANCE"]
    set    name_lower [string   tolower   $instname]

    set    fileName   $name_lower
    append fileName   ".xdc"
    append filePath   $fileName

    # Open a file for writing
    set outputFile [open $filePath "w"]
   
    ## Create CDC TIG constraints
    #puts $outputFile "set_false_path -from \[get_cells -hier -regexp {.*cdc_from.*}] -to \[get_cells  -hier -regexp {.*cdc_to.*}]"
    puts $outputFile "set_false_path -from \[get_cells -hier -regexp {.*cdc_from.*}]"

    puts $outputFile "#"
    puts $outputFile "#"
    puts $outputFile "\n"       

    # Close the file
    close $outputFile
} 

