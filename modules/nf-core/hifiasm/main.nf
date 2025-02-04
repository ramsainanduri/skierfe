process HIFIASM {
    tag "$meta.id"

    label 'process_high'
    label 'process_high_memory'
    label 'process_long'

    conda "bioconda::hifiasm=0.19.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/hifiasm:0.19.5--h5b5514e_1' :
        'biocontainers/hifiasm:0.19.5--h5b5514e_1' }"

    input:
    tuple val(meta),  path(reads), path(paternal_kmer_dump), path(maternal_kmer_dump)
    path  hic_read1
    path  hic_read2

    output:
    tuple val(meta), path("*.{dip,bp}.r_utg.gfa")      , emit: raw_unitigs
    tuple val(meta), path("*.{dip,bp}.r_utg.lowQ.bed") , emit: raw_unitigs_lowq        , optional: true
    tuple val(meta), path("*.{dip,bp}.r_utg.noseq.gfa"), emit: raw_unitigs_noseq       , optional: true
    tuple val(meta), path("*.ec.bin")                  , emit: corrected_reads
    tuple val(meta), path("*.ovlp.source.bin")         , emit: source_overlaps
    tuple val(meta), path("*.ovlp.reverse.bin")        , emit: reverse_overlaps
    tuple val(meta), path("*.{dip,bp}.p_utg.gfa")      , emit: processed_unitigs       , optional: true
    tuple val(meta), path("*.{dip,bp}.p_utg.lowQ.bed") , emit: processed_unitigs_lowq  , optional: true
    tuple val(meta), path("*.{dip,bp}.p_utg.noseq.gfa"), emit: processed_unitigs_noseq , optional: true
    tuple val(meta), path("*.{dip,bp}.p_ctg.gfa")      , emit: primary_contigs         , optional: true
    tuple val(meta), path("*.{dip,bp).p_ctg.lowQ.bed") , emit: primary_contigs_lowq    , optional: true
    tuple val(meta), path("*.{dip,bp}.p_ctg.noseq.gfa"), emit: primary_contigs_noseq   , optional: true
    tuple val(meta), path("*.hap1.p_ctg.gfa")          , emit: paternal_contigs        , optional: true
    tuple val(meta), path("*.hap2.p_ctg.gfa")          , emit: maternal_contigs        , optional: true
    tuple val(meta), path("*.hap1.p_ctg.lowQ.bed")     , emit: paternal_lowq           , optional: true
    tuple val(meta), path("*.hap2.p_ctg.lowQ.bed")     , emit: maternal_lowq           , optional: true
    tuple val(meta), path("*.hap1.p_ctg.noseq.gfa")    , emit: paternal_noseq          , optional: true
    tuple val(meta), path("*.hap2.p_ctg.noseq.gfa")    , emit: maternal_noseq          , optional: true
    path  "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if ((paternal_kmer_dump) && (maternal_kmer_dump) && (hic_read1) && (hic_read2)) {
        error "Hifiasm Trio-binning and Hi-C integrated should not be used at the same time"
    } else if ((paternal_kmer_dump) && !(maternal_kmer_dump)) {
        error "Hifiasm Trio-binning requires maternal data"
    } else if (!(paternal_kmer_dump) && (maternal_kmer_dump)) {
        error "Hifiasm Trio-binning requires paternal data"
    } else if ((paternal_kmer_dump) && (maternal_kmer_dump)) {
        """
        hifiasm \\
            $args \\
            -o ${prefix}.asm \\
            -t $task.cpus \\
            -1 $paternal_kmer_dump \\
            -2 $maternal_kmer_dump \\
            $reads

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            hifiasm: \$(hifiasm --version 2>&1)
        END_VERSIONS
        """
    } else if ((hic_read1) && !(hic_read2)) {
        error "Hifiasm Hi-C integrated requires paired-end data (only R1 specified here)"
    } else if (!(hic_read1) && (hic_read2)) {
        error "Hifiasm Hi-C integrated requires paired-end data (only R2 specified here)"
    } else if ((hic_read1) && (hic_read2)) {
        """
        hifiasm \\
            $args \\
            -o ${prefix}.asm \\
            -t $task.cpus \\
            --h1 $hic_read1 \\
            --h2 $hic_read2 \\
            $reads

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            hifiasm: \$(hifiasm --version 2>&1)
        END_VERSIONS
        """
    } else { // Phasing with Hi-C data is not supported yet
        """
        hifiasm \\
            $args \\
            -o ${prefix}.asm \\
            -t $task.cpus \\
            $reads

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            hifiasm: \$(hifiasm --version 2>&1)
        END_VERSIONS
        """
    }
}
