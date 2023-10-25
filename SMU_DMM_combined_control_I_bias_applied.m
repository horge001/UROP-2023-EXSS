function SMU_DMM_combined_control_I_bias_applied(compliance, start, stop, step, delay, testname)
    %%% This function applies a current bias!!!


    %Function used to control a Keithley 236 source-measure unit and
    %Thurlby-Thandar Instruments 1705 digital multimeter via GPIB and record
    %I-V measurements

    %Unit =SMU_DMM_combined_control(V, A, A, A, ms,'name_file.txt')

    % Input arguments:
    % Compliance(floating point number) = maximum value of voltage allowed to be measured,
    % Start(floating point number) = start value of the sweep
    % Stop(floating point number) = maximum value of the dual sweep (i.e
    % the end value of the forwards sweep and the start value of the
    % backwards sweep)
    % Step(floating point) = step between each value in the sweep
    % Delay = the time between each measurement
    % Testname = filename using within code and where measured data is stored, input as a .txt filename eg.
    % 'test1_270723.txt'
    % Outputs:
    % testname = output file with measured data
    % Subplot 1 = V_meas_4pp-I_bias scatter plot (4 point probe)
    % Subplot 2 = V_meas_2pp-I_bias scatter plot (2 point probe)
    % Subplot 3 = log(|R|)-I_bias scatter plot
    %Emma Horgan, August 2023
    
    instrreset %Resetting all instruments
    
    %DO NOT TOUCH CODE BELOW THIS POINT!
    
    %Connecting with instruments and establishing basic parameters
    
    
    %Connecting with Keithley 236 SMU
    keith236 = instrfind('Type', 'gpib', 'BoardIndex', 'PrimaryAdress', 'Tag', ''); %Sets instrument
        if isempty(keith236)
            keith236 = gpib('NI', 0, 16); %Sets instrument object in code, note: primary address of SMU is set by default to be 16
            keith236.Timeout = 1000; %Timeout value of instrument object, maximum =1000
        else
            fclose(keith236);
            keith236 = keith236(1);
        end
    fopen(keith236); %Opens communication with SMM
    
    %Connecting with Tti 1705 DMM
    dmm1705 = instrfind('Type', 'gpib', 'BoardIndex', 'PrimaryAdress', 'Tag', ''); %Sets instrument
    if isempty(dmm1705)
        dmm1705 = gpib('NI', 0, 1); %Sets instrument object in code, note: primary address of the DMM is set by default to 1 but can be changed on the front panel display
        dmm1705.Timeout = 1000; %Timeout value of instrument object
        fclose(dmm1705);
        dmm1705 = dmm1705(1);
    end
    fopen(dmm1705); %Opens communication with DMM
    
    
    
    %Setting up basic parameters and configurations of SMU
    fprintf(keith236, 'F1,0X'); %Setting SMU to source I and measure V, DC
    
    
    %Formatting for compliance command input string
    x='L';
    z=num2str(compliance);
    t=',';
    u='0X';
    compliance_in = strcat(x,z,t,u);
    %Setting the compliance voltage of the SMU with auto range (0)
    fprintf(keith236, compliance_in );
    fprintf(keith236, 'T1,0,0,0X'); %Triggering(T), origin  = IEEE GET(1), continuous - no trigger needed to continue source and measurement cycles (0), end = no output trigger, end = trigger disabled 
    
    
    %Setting the output data format
    fprintf(keith236, 'G4,2,0X'); % Returns measure value (4), ASCII data, no prefix or suffix (2), one line of dc data per talk (0)
    
    
    %Setting up basic configuration of DMM
    fprintf(dmm1705, 'VDC'); %Setting it to measure DC voltage 
    fprintf(dmm1705, 'AUTO'); %Setting the range to adjust automatically when needed
    
    
    
    
    %Taking measurements:
    %Creating array of applied currents
    I_app_forward=start:step:stop;
    I_app_backward=stop:-step:start;
    I_app=cat(2,I_app_forward, I_app_backward); %Joins the forward and back current sweep arrays together
    
    %Setting empty arrays for measured data to be stored in
    V_meas_smu=[];
    V_meas_dmm=[];
    
    fprintf(keith236, 'N1X'); %Turns the output of the SMU on, 1=ON, 0=OFF
    
    %Looping through all applied currents and measuring V from DMM and 
    % V from SMU
    for i=1 :length(I_app)
        %Formatting for input of applied currents
        a='B';
        b=num2str(I_app(i));
        c=',0,';
        d=num2str(delay);
        e='X';
        bias = strcat(a,b,c,d,e);
        fprintf(keith236, bias); %Applying ith element of applied current array, delay before applying it specified at top of code, autorange (0)
        V_meas_smu_new=query(keith236, 'H0X'); %Triggering the SMU to send the voltage  reading
        V_meas_dmm_new=query(dmm1705, 'READ?'); %Triggering the DMM to send the voltage reading
        V_meas_smu_new = str2double(V_meas_smu_new); %Converting measured voltage to a double
        V_meas_smu= [V_meas_smu,V_meas_smu_new]; %Adding measured value to the voltage array which stores all measured values
        V_meas_dmm_new_2 = extractBetween(V_meas_dmm_new, 1,10); %Extracting voltage values (removing unncessary characters in the string) and extracting only the numerical measured value
        %Converting between data types in matlab
        V_meas_dmm_new_2 = cell2mat(V_meas_dmm_new_2); 
        V_meas_dmm_new_2=str2double(V_meas_dmm_new_2);
        V_meas_dmm = [V_meas_dmm, V_meas_dmm_new_2]; %Adding measured value to the measured voltage array
    end
    
    fprintf(keith236, 'B0,0,0X'); %Setting the SMU to apply 0V immediately 
    fprintf(keith236, 'N0X'); %Turning off the output of the SMU
    
    
    %Initial plotting:
    %4 point probe
    %V_meas_4pp vs I_bias
    subplot(2,2,1)
    scatter(I_app,V_meas_dmm) %4 point probe plot
    xlabel('I_{bias}(A)')
    ylabel('V_{4pp}(V)')
    
    %2 point probe
    %V_meas_2pp vs I_bias
    subplot(2,2,2)
    scatter(I_app, V_meas_smu) %2 point probe plot
    xlabel('I_{bias}(A)')
    ylabel('V_{2pp}(V)')
    
    %log(R) against bias current
    R = V_meas_smu./I_app;
    y=log10(abs(R));
    subplot(2,2,3)
    scatter(I_app, y)
    xlabel('I_{bias}(A)')
    ylabel('log(|R|)')
    
    %Extracting the current and voltage data to a txt file
    A=[I_app;V_meas_dmm;V_meas_smu]; %Creates a 3D array of the voltage and current values
    A=A'; %Transposes array so that when it is converted to a table and text file it is the correct way round
    T=array2table(A, 'VariableNames',{'I_{bias}(A)','V_{4pp}(V)', 'V_{2pp}(A)'}); %Converts array to table with headers
    writetable(T, testname, 'Delimiter','\t') %Converts table to .txt file with tab delimiters
    
    %Closing communciation with both instruments
    fclose(keith236);
    fclose(dmm1705);
end
