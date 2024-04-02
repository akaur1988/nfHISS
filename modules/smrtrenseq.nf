process Canu {
  container 'docker://swiftseal/smrtrenseq:latest'
  cpus 8
  memory { 16.GB * task.attempt }
  maxRetries 3
  time '24h'
  input:
  tuple val(sample), path(reads)
  output:
  tuple val(sample), path("assembly/assembly.contigs.fasta")
  script:
  """
  canu \
    -d assembly \
    -p assembly \
    genomeSize=70m
    useGrid=false \
    -pacbio-hifi $reads \
    maxInputCoverage=20000
  """
}

process SeqkitStats {
  container
}

workflow smrtrenseq {
  trimmed_reads = Cutadapt(reads)
  assembly = Canu(trimmed_reads)
}
