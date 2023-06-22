task AlignIndels{
    File casesVCF
    File ref
    Int threads

    command {
      bcftools norm -m -any -f ${ref} ${casesVCF} -o cases.out.vcf
    }
    runtime {
        docker : "vandhanak/bcftools:1.3.1"
        cpu : "${threads}"
	    memory : "64 GB"
	    disks : "local-disk 1500 HDD"
    }
    output{
        File outVCF="cases.out.vcf"
    }
}

task Annotate{
    File VCFtoAnn
    File ref
    Int threads
    command {
    vep --cache --offline --canonical --vcf -i ${VCFtoAnn} -o cases.ann.vcf.gz --compress_out gzip
    }
    runtime {
        docker : "evanschafer/ensemblvep:GRCh38"
        cpu : "${threads}"
        memory : "64 GB"
        disks : "local-disk 1500 HDD"
    }
    output{
        File annVCF="cases.ann.vcf.gz"
    }
}

task Makesnpfile{
    File AnnotatedVCF
    Int threads
    command {
    python2.7 /make_snp_file.py --vcffile ${AnnotatedVCF} --outfile casesnp.txt --genecolname Gene --vep --includevep Consequence[=]synonymous_variant --excludevep BIOTYPE[=]protein_coding 
    }
    runtime {
        docker : "evanschafer/burdentest:v2"
        cpu : "${threads}"
        memory : "64 GB"
        disks : "local-disk 1500 HDD"
    }
    output{
        File outTXT="casesnp.txt"
    }
}

task Countcases{
    File AnnotatedVCF
    Int threads
    File SNP
    command {
    python2.7 /count_cases.py -v ${AnnotatedVCF} -s ${SNP} -o casecounts.txt
    }
    runtime {
        docker : "evanschafer/burdentest:v2"
        cpu : "${threads}"
        memory : "64 GB"
        disks : "local-disk 1500 HDD"
    }
    output{
        File outTXT="casecounts.txt"
    }
}

task ControlAnnotate{
    File ControlVCFtoAnn
    File ref
    Int threads
    command {
    vep --cache --offline --canonical --vcf -i ${ControlVCFtoAnn} -o controls.ann.vcf.gz --compress_out gzip
    }
    runtime {
        docker : "evanschafer/ensemblvep:GRCh38"
        cpu : "${threads}"
        memory : "64 GB"
        disks : "local-disk 1500 HDD"
    }
    output{
        File annVCF="controls.ann.vcf.gz"
    }
}

task ControlMakesnpfile{
    File ControlAnnotatedVCF
    Int threads
    command {
    python2.7 /make_snp_file.py --vcffile ${ControlAnnotatedVCF} --outfile controlsnp.txt --genecolname Gene --vep --includevep Consequence[=]synonymous_variant --excludevep BIOTYPE[=]protein_coding 
    }
    runtime {
        docker : "evanschafer/burdentest:v2"
        cpu : "${threads}"
        memory : "64 GB"
        disks : "local-disk 1500 HDD"
    }
    output{
        File outTXT="controlsnp.txt"
    }
}

task Countcontrols{
    File ControlAnnotatedVCF
    Int threads
    File ControlSNP
    command {
    python2.7 /count_controls.py -v ${ControlAnnotatedVCF} -s ${ControlSNP} -o controlcounts.txt
    }
    runtime {
        docker : "evanschafer/burdentest:v2"
        cpu : "${threads}"
        memory : "64 GB"
        disks : "local-disk 1500 HDD"
    }
    output{
        File outTXT="controlcounts.txt"
    }
}


workflow Burdentestv1{
    File casesVCF
    File ControlVCF
    File ref
    Int threads

    call AlignIndels{
        input:
            casesVCF=casesVCF,
            ref=ref,
            threads=threads,
    }

    call Annotate{
        input:
            VCFtoAnn=AlignIndels.outVCF,
            ref=ref,
            threads=threads,
    }

    call Makesnpfile{
        input:
            AnnotatedVCF=Annotate.annVCF,
            threads=threads,
    } 

    call Countcases{
        input:
            AnnotatedVCF=Annotate.annVCF,
            threads=threads,
            SNP=Makesnpfile.outTXT,
    } 


    call ControlAnnotate{
        input:
            ControlVCFtoAnn=ControlVCF,
            ref=ref,
            threads=threads,
    }

    call ControlMakesnpfile{
        input:
            ControlAnnotatedVCF=ControlAnnotate.annVCF,
            threads=threads,
    } 

    call Countcontrols{
        input:
            ControlAnnotatedVCF=ControlAnnotate.annVCF,
            threads=threads,
            ControlSNP=ControlMakesnpfile.outTXT,
    } 
}
