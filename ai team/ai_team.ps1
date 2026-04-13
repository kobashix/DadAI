param (
    [Parameter(Mandatory=$true)]
    [string]$Task
)

[console]::OutputEncoding = [System.Text.Encoding]::UTF8

$MaxIterations = 3
$Iteration = 1

Write-Host "Assigning task to Gemini Flash: $Task" -ForegroundColor Cyan
$WorkerOutput = $Task | llm -m gemini-2.5-flash

while ($Iteration -le $MaxIterations) {
    Write-Host "--- Iteration $Iteration ---" -ForegroundColor Yellow
    
    # Base Supervisor Persona
    $SystemPrompt = "You are a ruthless, senior code reviewer. You must aggressively attempt to find flaws in efficiency, security, or edge-case handling."
    
    # 33% chance Middle Management interjects
    if ((Get-Random -Minimum 1 -Maximum 4) -eq 1) {
        Write-Host "Middle Management is interrupting..." -ForegroundColor Magenta
        $ManagerDistraction = $WorkerOutput | llm -m gemini-2.5-flash -s "You are a lazy, incompetent middle manager. Ask one brief, incredibly stupid, corporate-buzzword-filled question about this code that wastes the senior engineer's time."
        Write-Host "Manager: $ManagerDistraction" -ForegroundColor DarkGray
        
        # Force the supervisor to deal with it
        $SystemPrompt += " Before reviewing the code, you must politely answer this stupid question from your manager: '$ManagerDistraction'. If the code is 100% flawless, end your response with the word 'APPROVED'. Otherwise, list the exact issues."
    } else {
        $SystemPrompt += " If the code is 100% flawless, reply with ONLY the word 'APPROVED'. Otherwise, list the exact issues."
    }

    Write-Host "Gemini Supervisor is reviewing the work..." -ForegroundColor Cyan
    $SupervisorReview = $WorkerOutput | llm -m gemini-2.5-flash -s $SystemPrompt

    if ($SupervisorReview -match "APPROVED") {
        if ($SupervisorReview.Length -gt 15) {
            Write-Host "Supervisor response:`n$SupervisorReview" -ForegroundColor DarkCyan
        }
        Write-Host "Gemini APPROVED the work!" -ForegroundColor Green
        $WorkerOutput | Out-File -FilePath "final_output.txt" -Encoding utf8
        Write-Host "Result saved to final_output.txt" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Gemini REJECTED the work. Sending feedback for revision..." -ForegroundColor Red
        
        $RevisionPrompt = @"
Your previous work was rejected. Here was your work:
$WorkerOutput

Here is the supervisor's feedback:
$SupervisorReview

Rewrite the solution to fix all mentioned issues. Ignore any management buzzwords. Output ONLY the fixed solution.
"@
        $WorkerOutput = $RevisionPrompt | llm -m gemini-2.5-flash
    }

    $Iteration++
}

Write-Host "Maximum iterations reached without approval. Saving last output..." -ForegroundColor Yellow
$WorkerOutput | Out-File -FilePath "final_output.txt" -Encoding utf8
Write-Host "Last output saved to final_output.txt" -ForegroundColor Yellow
