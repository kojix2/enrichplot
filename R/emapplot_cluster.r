##' @rdname emapplot_cluster
##' @exportMethod emapplot_cluster
setMethod("emapplot_cluster", signature(x = "enrichResult"),
    function(x, showCategory = nrow(x), color = "p.adjust", ...) {
        emapplot_cluster.enrichResult(x, showCategory = showCategory, color = color, ...)
    })

##' @rdname emapplot_cluster
##' @exportMethod emapplot_cluster
setMethod("emapplot_cluster", signature(x = "gseaResult"),
    function(x, showCategory = nrow(x), color = "p.adjust", ...) {
        emapplot_cluster.enrichResult(x, showCategory = showCategory, color = color, ...)
    })

##' @rdname emapplot_cluster
##' @exportMethod emapplot_cluster
setMethod("emapplot_cluster", signature(x = "compareClusterResult"),
    function(x, showCategory = 30, color = "p.adjust", ...) {  
        emapplot_cluster.compareClusterResult(x, showCategory = showCategory, color=color, ...)
    })


##' @rdname emapplot_cluster
##' @param with_edge if TRUE, draw the edges of the network diagram
##' @param line_scale scale of line width
##' @param method method of calculating the similarity between nodes, one of "Resnik",
##' "Lin", "Rel", "Jiang" , "Wang"  and "JC" (Jaccard similarity coefficient) methods
##' @param nWords the number of words in the cluster tags
##' @param nCluster the number of clusters
##' @param split separate result by 'category' variable
##' @param min_edge minimum percentage of overlap genes to display the edge, should between 0 and 1, default value is 0.2
##' @param cluster_label_scale scale of cluster labels size
##' @param semData GOSemSimDATA object
##' @param label_style one of "shadowtext" and "ggforce"
##' @param group_legend If TRUE, the grouping legend will be displayed. The default is FALSE
##' @param node_scale scale of node(for "enrichResult" data) or pie chart(for "compareClusterResult" data)
##' @importFrom igraph layout_with_fr
##' @importFrom ggplot2 aes_
##' @importFrom ggplot2 scale_color_discrete
##' @importFrom ggplot2 scale_size_continuous
##' @importFrom ggplot2 scale_fill_discrete
##' @importFrom stats kmeans
##' @importFrom ggraph ggraph
##' @importFrom ggraph geom_node_point
##' @importFrom ggraph geom_edge_link
##' @importFrom DOSE geneInCategory
##' @importFrom GOSemSim godata
##' @importFrom shadowtext geom_shadowtext
##' @importFrom ggnewscale new_scale_fill
##' @importFrom magrittr %>%
emapplot_cluster.enrichResult <- function(x, showCategory = nrow(x), color = "p.adjust", line_scale = 0.1, with_edge = TRUE,
     method = "JC", nWords = 4, nCluster = NULL, split = NULL, min_edge = 0.2, cluster_label_scale = 1, semData = NULL,
     label_style = "shadowtext", group_legend = FALSE, node_scale = 1){

    n <- update_n(x, showCategory)
    y <- as.data.frame(x)

    g <- get_igraph(x=x, y=y, n=n, color=color, line_scale=line_scale, min_edge=min_edge,
        method = method, semData = semData)
    if(n == 1) {
        return(ggraph(g) + geom_node_point(color="red", size=5) + geom_node_text(aes_(label=~name)))
    }
    edgee <- igraph::get.edgelist(g)
    ## Get the semantic similarity or overlap between two nodes

    edge_w <- E(g)$weight
    set.seed(123)
    lw <- layout_with_fr(g, weights=edge_w)

    p <- ggraph::ggraph(g, layout=lw)
    # cluster_label1 <- lapply(clusters, function(i){i[order(y[i, "pvalue"])[1]]})

    ## Using k-means clustering to group
    pdata2 <- p$data
    dat <- data.frame(x = pdata2$x, y = pdata2$y)
    colnames(pdata2)[5] <- "color2"

    if(is.null(nCluster)){
        pdata2$color <- kmeans(dat, ceiling(sqrt(nrow(dat))))$cluster
    } else {
        if(nCluster > nrow(dat)) nCluster <- nrow(dat)
        pdata2$color <- kmeans(dat, nCluster)$cluster
    }

    goid <- y$ID
    cluster_color <- unique(pdata2$color)
    clusters <- lapply(cluster_color, function(i){goid[which(pdata2$color == i)]})
    cluster_label <- sapply(cluster_color, wordcloud_i, pdata2 = pdata2, nWords=nWords)
    names(cluster_label) <- cluster_color
    pdata2$color <- cluster_label[as.character(pdata2$color)]
    p$data <- pdata2
    ## Take the location of each group's center nodes as the location of the label
    label_x <- stats::aggregate(x ~ color, pdata2, mean)
    label_y <- stats::aggregate(y ~ color, pdata2, mean)
    label_location <- data.frame(x = label_x$x, y = label_y$y, label = label_x$color)

    ## Adjust the label position up and down to avoid overlap
    # rownames(label_location) <- label_location$label
    # label_location <- adjust_location(label_location, x_adjust, y_adjust)
    ## use spread.labs
    # label_location$y <- TeachingDemos::spread.labs(x = label_location$y, mindiff = cluster_label_scale*y_adjust)
    show_legend <- c(group_legend, FALSE)
    names(show_legend) <- c("fill", "color")

    if(with_edge) {
        p <-  p +  ggraph::geom_edge_link(alpha = .8, aes_(width =~ I(width*line_scale)), colour='darkgreen')
    }
    
    if(label_style == "shadowtext") {
        p <- p + ggforce::geom_mark_ellipse(aes_(x =~ x, y =~ y, color =~ color, fill =~ color), 
            show.legend = show_legend)
    } else {
        p <- p + ggforce::geom_mark_ellipse(aes_(x =~ x, y =~ y, color =~ color, fill =~ color, label =~ color), 
            show.legend = show_legend)
    }

    if(group_legend) p <- p + scale_fill_discrete(name = "groups") 
    p <- p + new_scale_fill() + geom_point(shape = 21, aes_(x =~ x, y =~ y, fill =~ color2, size =~ size)) +
        scale_size_continuous(name = "number of genes", range=c(3, 8) * node_scale) +
        scale_fill_continuous(low = "red", high = "blue", name = color, guide = guide_colorbar(reverse = TRUE))  
        # geom_shadowtext(data = label_location, aes_(x =~ x, y =~ y, label =~ label),
            # size = 5 * cluster_label_scale)
    if(label_style == "shadowtext") {
        if (utils::packageVersion("ggrepel") >= "0.9.0") {
            p <- p + ggrepel::geom_text_repel(data = label_location, aes_(x =~ x, y =~ y, label =~ label, colour =~ label),
                size = 5 * cluster_label_scale, bg.color = "white", bg.r = 0.3, show.legend = FALSE)
        } else {
            warn <- paste0("The version of ggrepel in your computer is ", utils::packageVersion('ggrepel'), 
                ", please install the latest version in Github: devtools::install_github('slowkow/ggrepel')")
            warning(warn)
            p <- p + ggrepel::geom_text_repel(data = label_location, aes_(x =~ x, y =~ y, label =~ label),
                size = 5 * cluster_label_scale)
        }
        
    }  

    p + theme(legend.title = element_text(size = 15), 
              legend.text  = element_text(size = 15))   
}



##' @rdname emapplot_cluster
##' @importFrom igraph E 
##' @importFrom ggplot2 aes_
##' @importFrom ggplot2 coord_equal
##' @importFrom ggraph ggraph
##' @importFrom ggraph geom_edge_link
##' @importFrom scatterpie geom_scatterpie
##' @importFrom scatterpie geom_scatterpie_legend
##' @importClassesFrom DOSE compareClusterResult
##' @importFrom ggnewscale new_scale_fill
##' @importFrom stats setNames
##' @param pie proportion of clusters in the pie chart, one of 'equal' (default) or 'Count'
##' @param pie_scale scale of pie chart or point, this parameter has been changed to "node_scale"
##' @param legend_n number of circle in legend
emapplot_cluster.compareClusterResult <- function(x, showCategory = 30, color = "p.adjust", line_scale = 0.1, with_edge = TRUE,
    method = "JC", nWords = 4, nCluster = NULL, split = NULL, min_edge = 0.2, cluster_label_scale = 1, semData = NULL,
    pie = "equal", legend_n = 5, node_scale = NULL, pie_scale = NULL, label_style = "shadowtext", group_legend = FALSE){
    
    if (!is.null(pie_scale)) message("pie_scale parameter has been changed to 'node_scale'")
    
    if (is.null(node_scale)) {
        if (!is.null(pie_scale)) {
            node_scale <- pie_scale 
        } else {
            node_scale <- 1
        }
    }
    
    
    y <- fortify(x, showCategory=showCategory, includeAll=TRUE, split=split)
    y$Cluster = sub("\n.*", "", y$Cluster)
    
    y_union <- get_y_union(y = y, showCategory = showCategory)  
    y <- y[y$ID %in% y_union$ID, ]
    
    geneSets <- setNames(strsplit(as.character(y_union$geneID), "/", fixed = TRUE), y_union$ID)
    g <- emap_graph_build(y=y_union,geneSets=geneSets,color=color, line_scale=line_scale, min_edge=min_edge, 
        method = method, semData = semData)
    p <- get_p(y = y, g = g, y_union = y_union, node_scale = node_scale, pie = pie, layout = "nicely")
    if (is.null(dim(y)) | nrow(y) == 1 | is.null(dim(y_union)) | nrow(y_union) == 1) 
        return(p)
          
    ## then add the pie plot
    ## Get the matrix data for the pie plot
    ID_Cluster_mat <- prepare_pie_category(y,pie=pie)
      
    # Start the cluster diagram 
    edge_w <- E(g)$weight
    set.seed(123)
    lw <- layout_with_fr(g, weights=edge_w)    
    p <- ggraph(g, layout=lw)
    
    ## Using k-means clustering to group
    pdata2 <- p$data
    dat <- data.frame(x = pdata2$x, y = pdata2$y)
    colnames(pdata2)[5] <- "color2"
    
    if(is.null(nCluster)){
        pdata2$color <- kmeans(dat, ceiling(sqrt(nrow(dat))))$cluster
    } else {
        if(nCluster > nrow(dat)) nCluster <- nrow(dat)
        pdata2$color <- kmeans(dat, nCluster)$cluster
    }

    goid <- y_union$ID
    cluster_color <- unique(pdata2$color)
    clusters <- lapply(cluster_color, function(i){goid[which(pdata2$color == i)]})
    cluster_label <- sapply(cluster_color,  wordcloud_i, pdata2 = pdata2, nWords=nWords)
    names(cluster_label) <- cluster_color
    pdata2$color <- cluster_label[as.character(pdata2$color)]
    p$data <- pdata2
    
    #plot the edge
    #get the X-coordinate and y-coordinate of pies
    pdata2 <- p$data
    
    desc <- y_union$Description[match(rownames(ID_Cluster_mat), y_union$Description)]
    i <- match(desc, pdata2$name)
    
    ID_Cluster_mat$x <- pdata2$x[i]
    ID_Cluster_mat$y <- pdata2$y[i]
    
    #Change the radius value to fit the pie plot
    radius <- NULL
    ID_Cluster_mat$radius <- sqrt(pdata2$size[i] / sum(pdata2$size)) * node_scale
    
    x_loc1 <- min(ID_Cluster_mat$x)
    y_loc1 <- min(ID_Cluster_mat$y)
    
    ## Take the location of each group's center nodes as the location of the label
    label_x <- stats::aggregate(x ~ color, pdata2, mean)
    label_y <- stats::aggregate(y ~ color, pdata2, mean)
    label_location <- data.frame(x = label_x$x, y = label_y$y, label = label_x$color)
    
    ## Adjust the label position up and down to avoid overlap
    # rownames(label_location) <- label_location$label
    # label_location <- adjust_location(label_location, x_adjust, y_adjust)
    # label_location$y <- TeachingDemos::spread.labs(x = label_location$y, mindiff = cluster_label_scale*y_adjust)
    show_legend <- c(group_legend, FALSE)
    names(show_legend) <- c("fill", "color")
    
    if(with_edge) {
        p <-  p +  geom_edge_link(alpha = .8, aes_(width =~ I(width*line_scale)), colour='darkgreen')
    }
    
    if(label_style == "shadowtext") {
        p <- p + ggforce::geom_mark_ellipse(aes_(x =~ x, y =~ y, color =~ color, fill =~ color), 
            show.legend = show_legend)
    } else {
        p <- p + ggforce::geom_mark_ellipse(aes_(x =~ x, y =~ y, color =~ color, fill =~ color, label =~ color), 
            show.legend = show_legend)
    }
    
    if(group_legend) p <- p + scale_fill_discrete(name = "groups")   
    
    p <- p + new_scale_fill() + geom_scatterpie(aes_(x=~x,y=~y,r=~radius), data=ID_Cluster_mat,
            cols=colnames(ID_Cluster_mat)[1:(ncol(ID_Cluster_mat)-3)],color=NA) +
        coord_equal()+ 
        geom_scatterpie_legend(ID_Cluster_mat$radius, x=x_loc1, y=y_loc1, n = legend_n,
            labeller=function(x) round(sum(pdata2$size)*((x/node_scale)^2)))          
        # geom_shadowtext(data = label_location, aes_(x =~ x, y =~ y, label =~ label),
            # size = 5 * cluster_label_scale, check_overlap = check_overlap)
            
    if(label_style == "shadowtext") {
        if (utils::packageVersion("ggrepel") >= "0.9.0") {
            p <- p + ggrepel::geom_text_repel(data = label_location, aes_(x =~ x, y =~ y, label =~ label, colour =~ label),
                size = 5 * cluster_label_scale, bg.color = "white", bg.r = 0.3, show.legend = FALSE)
        } else {
            warn <- paste0("The version of ggrepel in your computer is ", utils::packageVersion('ggrepel'), 
                ", please install the latest version in Github: devtools::install_github('slowkow/ggrepel')")
            warning(warn)
            p <- p + ggrepel::geom_text_repel(data = label_location, aes_(x =~ x, y =~ y, label =~ label),
                size = 5 * cluster_label_scale)
        }
        
    }
    p + theme(legend.title = element_text(size = 15), 
              legend.text  = element_text(size = 15))
               
     
}
































