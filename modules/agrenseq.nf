process CountKmers {
    container 'kmc'
    cpus 4
    memory { 8.GB * task.attempt }
    time '1h'
    input:
    tuple val(sample), path(read1), path(read2)
    output:
    tuple val(sample), path("${sample}.dump")
    script:
    """
    cat $read1 $read2 > reads.fq.gz
    kmc -k51 -m8 -t${task.cpus} reads.fq.gz kmc_output
    kmc_tools transform kmc_output -ci10 dump ${sample}.dump
    """
}

process CreatePresenceMatrix {
    cpus 1
    memory { 8.GB * task.attempt }
    input:
    path accession_table
    output:
    path 'presence_matrix.txt'
    script:
    """
    CreatePresenceMatrix.sh -i $accession_table -o presence_matrix.txt
    """
}

process NLRParser {
    conda 'meme=5.4.1=py310pl5321h9f004f7_2'
    cpus 4
    memory { 4.GB * task.attempt }
    input:
    path assembly
    output:
    path 'nlrparser.txt'
    script:
    """
    NLR_Parser.sh -t ${task.cpus} -i $assembly -o nlrparser.txt
    """
}

process RunAssociation {
    cpus 1
    memory { 16.GB * task.attempt }
    time '6h'
    publishDir 'results'
    input:
    path presence_matrix
    path assembly
    path phenotype
    path nlrparser
    output:
    path 'agrenseq_result.txt'
    script:
    """
    RunAssociation.sh -i $presence_matrix -n $nlrparser -p $phenotype -a $assembly -o agrenseq_result.txt
    """
}

workflow agrenseq {
    accession_table = Channel
        .fromPath(params.reads)
        .splitCsv(header: true, sep: "\t")
        .map { row -> tuple(row.sample, file(row.forward), file(row.reverse)) } \
        | CountKmers \
        | map { it -> "${it[0]}\t${it[1]}" } \
        | collectFile(name: "accession.tsv", newLine: true)

    phenotype_file = Channel
        .fromPath(params.reads)
        .splitCsv(header: true, sep: "\t")
        .map { row -> "${row.sample}\t${row.score}" } \
        | collectFile(name: "phenotype.tsv", newLine: true)

    matrix = CreatePresenceMatrix(accession_table)

    assembly = Channel
        .fromPath(params.assembly)

    nlrparser = NLRParser(assembly)

    association = RunAssociation(matrix, assembly, phenotype_file, nlrparser)
}
