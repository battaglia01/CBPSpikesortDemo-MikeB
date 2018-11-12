function InitializeWaveformPlot(command)
    global params dataobj;

    if nargin == 1 & isequal(command, 'disable')
        DeleteCalibrationTab('Initial Waveforms, Clusters');
        DeleteCalibrationTab('Initial Waveforms, Shapes');
        return;
    end

% -------------------------------------------------------------------------
% Set up basics
    %set up local vars
    XProj = dataobj.clustering.XProj;
    assignments = dataobj.clustering.assignments;
    X = dataobj.clustering.X;
    nchan = dataobj.whitening.nchan;
    threshold = params.clustering.spike_threshold;
    dt = dataobj.whitening.dt;

    % XProj : snippet x PC-component matrix of projections
    % assignments : vector of class assignments
    % X : time x snippet-index matrix of data
    if (~exist('marker', 'var'))
        marker = '.';
    end

    num_clusters = max(assignments);
    colors = hsv(num_clusters);
    centroids = zeros(size(X, 1), num_clusters);
    projCentroids = zeros(size(XProj,2), num_clusters);
    counts = zeros(num_clusters, 1);
    distances = zeros(size(X,2),1);
    for i=1:num_clusters
      spikeIinds = find(assignments==i);
      centroids(:, i) = mean(X(:, spikeIinds), 2);
      projCentroids(:,i) = mean(XProj(spikeIinds,:)', 2);
      counts(i) = length(spikeIinds);
      distances(spikeIinds) = sqrt(sum((XProj(spikeIinds,:)' - ...
           repmat(projCentroids(:,i),1,counts(i))).^2))';
    end

% -------------------------------------------------------------------------
% Plot PCs (Tab 1)
    CreateCalibrationTab('Initial Waveforms, Clusters', 'InitializeWaveform');
    cla('reset');
    hold on;

    for i=1:num_clusters     %plot central cluster first
        idx = ((assignments == i) & (distances<threshold));
        plot(XProj(idx, 1), XProj(idx, 2), ...
             '.', 'Color', 0.5*colors(i, :)+0.5*[1 1 1], ...
             'Marker', marker, 'MarkerSize', 8);
    end
    for i=1:num_clusters     %plot outliers second
        idx = ((assignments == i) & (distances>=threshold));
        plot(XProj(idx, 1), XProj(idx, 2), ...
             '.', 'Color', 0.5*colors(i, :)+0.5*[1 1 1], ...
             'Marker', marker, 'MarkerSize', 8);
    end
    centhandles = [];
    for i=1:num_clusters
      zsc = norm(projCentroids(:,i));
      centhandles(i) = plot(projCentroids(1,i), projCentroids(2,i), 'o', ...
          'MarkerSize', 9, 'LineWidth', 2, 'MarkerEdgeColor', 'black', ...
          'MarkerFaceColor', colors(i,:), 'DisplayName', ...
          ['Cell ' num2str(i) ', amplitude=' num2str(zsc)]);
    end
    xl = get(gca, 'XLim'); yl = get(gca, 'YLim');
    plot([0 0], yl, '-', 'Color', 0.8 .* [1 1 1]);
    plot(xl, [0 0], '-', 'Color', 0.8 .* [1 1 1]);
    th=linspace(0, 2*pi, 64);
    nh= plot(threshold*sin(th),threshold*cos(th), 'k', 'LineWidth', 2, ...
        'DisplayName', sprintf('Spike threshold = %.1f',threshold));
    legend([nh centhandles]);
    axis equal
    hold off
    font_size = 12;
    set(gca, 'FontSize', font_size);
    xlabel('PC 1'); ylabel('PC 2');
    title(sprintf('Clustering result (%d clusters)', num_clusters));

% -------------------------------------------------------------------------
% Plot the time-domain snippets (Tab 2)
    CreateCalibrationTab('Initial Waveforms, Shapes', 'InitializeWaveform');
    hold on;
    nc = ceil(sqrt(num_clusters));
    nr = ceil((num_clusters)/nc);
    chOffset = 13; %**Magic vertical spacing between channels
    wlen = size(X, 1) / nchan;
    MAX_TO_PLOT = 1e2;
    yrg = zeros(num_clusters,1);
    for i = 1:num_clusters
        Xsub = X(:, assignments == i);
        if isempty(Xsub), continue; end
        if (size(Xsub, 2) > MAX_TO_PLOT)
            Xsub = Xsub(:, randsample(size(Xsub, 2), MAX_TO_PLOT, false));
        end
        Xsub = Xsub + chOffset*floor(([1:(nchan*wlen)]'-1)/wlen)*ones(1,size(Xsub,2));
        centroid = centroids(:,i) + chOffset*floor(([1:(nchan*wlen)]'-1)/wlen);

        subplot(nc, nr, i); cla;
        hold on;

        t_ms = (1:wlen)*dt*1000;
        plot(t_ms, reshape(Xsub,wlen,[]), 'Color', 0.25*colors(i,:)+0.75*[1 1 1]);
        plot(t_ms, reshape(centroid,wlen,[]), 'Color', colors(i,:), 'LineWidth', 2);

        xlim([0, wlen+1]);
        yrg(i) = (max(Xsub(:))-min(Xsub(:)));
        axis tight; %%@fixes display issues
        set(gca, 'FontSize', font_size);
        xlabel('Time (ms)');
        title(sprintf('Cell %d, SNR=%.1f', i, norm(centroids(:,i))/sqrt(size(centroids,1))));
        hold off
    end

    % make axis ticks same size on all subplots
    mxYrg = max(yrg);
    for i = 1:num_clusters
      subplot(nc,nr,i);
      ylim=get(gca,'Ylim');
      ymn = mean(ylim);
      yrg = ylim(2)-ylim(1);
      set(gca,'Ylim', ymn + (ylim - ymn)*(mxYrg/yrg));
    end

    ip = centroids'*centroids;
    dist2 = repmat(diag(ip),1,size(ip,2)) - 2*ip + repmat(diag(ip)',size(ip,1),1) +...
            diag(diag(ip));
    fprintf(1,'Distances between waveforms (diagonal is norm): \n');
    disp(sqrt(dist2/size(centroids,1)));

    return