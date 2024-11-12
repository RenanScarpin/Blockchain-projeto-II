// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ElectionContract {
    address public owner;
    uint256 public electionCount;

    constructor() {
        owner = msg.sender;
    }

    // Struct para guardar informações do candidato
    struct Candidate {
        uint256 id;
        string name;
    }

    // Struct para guardar informações das eleições
    struct Election {
        string name;
        bool started;
        bool closed;
        uint256 candidateCount;
        uint256 totalVotes;
        mapping(uint256 => Candidate) candidates; // candidateId => Candidate
        uint256[] candidateIds;
        mapping(uint256 => uint256) candidateVotes; // candidateId => votes
        mapping(address => uint256) voterTotalVotes; // voter => total votes
        mapping(address => mapping(uint256 => uint256)) voterCandidateVotes; // voter => candidateId => votes
    }

    mapping(uint256 => Election) public elections; // electionId => Election

    // Eventos para transparência
    event ElectionCreated(uint256 electionId, string name);
    event CandidateAdded(uint256 electionId, uint256 candidateId, string candidateName);
    event ElectionStarted(uint256 electionId);
    event ElectionClosed(uint256 electionId);
    event VoteCast(uint256 electionId, uint256 candidateId, address voter, uint256 numVotes);

    // Modificador para restringir acesso ao dono
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    // Cria uma nova eleição dado seu nome
    function createElection(string memory _name) public onlyOwner returns (uint256) {
        electionCount++;
        Election storage e = elections[electionCount];
        e.name = _name;
        e.started = false;
        e.closed = false;
        e.candidateCount = 0;
        emit ElectionCreated(electionCount, _name);
        return electionCount;
    }
    
    // Adiciona um candidato a uma eleição dado o ID da eleição e nome do candidato
    function addCandidate(uint256 _electionId, string memory _candidateName) public onlyOwner returns (uint256) {
        Election storage e = elections[_electionId];
        require(!e.started, "Cannot add candidate after election has started");
        e.candidateCount++;
        uint256 candidateId = e.candidateCount;
        e.candidates[candidateId] = Candidate(candidateId, _candidateName);
        e.candidateIds.push(candidateId);
        e.candidateVotes[candidateId] = 0;
        emit CandidateAdded(_electionId, candidateId, _candidateName);
        return candidateId;
    }

    // Inicia a eleição dado seu ID, permitindo a recepção de votos
    function startElection(uint256 _electionId) public onlyOwner {
        Election storage e = elections[_electionId];
        require(!e.started, "Election already started");
        require(!e.closed, "Election is closed");
        e.started = true;
        emit ElectionStarted(_electionId);
    }
    
    // Fecha a eleição dado seu ID, tornando impossível a recepção de votos
    function closeElection(uint256 _electionId) public onlyOwner {
        Election storage e = elections[_electionId];
        require(e.started, "Election not started yet");
        require(!e.closed, "Election already closed");
        e.closed = true;
        emit ElectionClosed(_electionId);
    }
    
    // Vota em um candidato dado o ID da eleição, ID do candidato e número de votos a serem emitidos
    function vote(uint256 _electionId, uint256 _candidateId, uint256 _numVotes) public {
        Election storage e = elections[_electionId];
        require(e.started, "Election not started yet");
        require(!e.closed, "Election is closed");
        require(_candidateId > 0 && _candidateId <= e.candidateCount, "Candidate does not exist");

        e.candidateVotes[_candidateId] += _numVotes;
        e.totalVotes += _numVotes;
        e.voterTotalVotes[msg.sender] += _numVotes;
        e.voterCandidateVotes[msg.sender][_candidateId] += _numVotes;

        emit VoteCast(_electionId, _candidateId, msg.sender, _numVotes);
    }

    // Retorna quantos votos um dado candidato em uma dada eleição recebeu, dado o ID da eleição e ID do candidato
    function getCandidateVotes(uint256 _electionId, uint256 _candidateId) public view returns (uint256) {
        Election storage e = elections[_electionId];
        return e.candidateVotes[_candidateId];
    }

    // Retorna em porcentagem quantos votos um dado candidato em uma dada eleição recebeu, dado o ID da eleição e ID do candidato
    function getCandidateVotePercentage(uint256 _electionId, uint256 _candidateId) public view returns (uint256) {
        Election storage e = elections[_electionId];
        if (e.totalVotes == 0) return 0;
        return (e.candidateVotes[_candidateId] * 100) / e.totalVotes;
    }

    // Retorna o total de votos realizados em uma eleição dado seu ID
    function getTotalVotes(uint256 _electionId) public view returns (uint256) {
        Election storage e = elections[_electionId];
        return e.totalVotes;
    }

    // Retorna quantos votos foram emitidas por uma conta (urna) em uma dada eleição, dado o ID da eleição e endereço da urna
    function getVoterTotalVotes(uint256 _electionId, address _voter) public view returns (uint256) {
        Election storage e = elections[_electionId];
        return e.voterTotalVotes[_voter];
    }

    // Retorna quantos votos foram emitidas por uma conta (urna) para um candidato específico em uma dada eleição, 
    // dado o ID da eleição, ID do candidato e endereço da urna
    function getVoterCandidateVotes(uint256 _electionId, address _voter, uint256 _candidateId) public view returns (uint256) {
        Election storage e = elections[_electionId];
        return e.voterCandidateVotes[_voter][_candidateId];
    }

    // Retorna em porcentagem quantos votos foram emitidas por uma conta (urna) para um candidato específico em uma dada eleição, 
    // dado o ID da eleição, ID do candidato e endereço da urna
    function getVoterCandidateVotePercentage(uint256 _electionId, address _voter, uint256 _candidateId) public view returns (uint256) {
        Election storage e = elections[_electionId];
        uint256 voterTotal = e.voterTotalVotes[_voter];
        if (voterTotal == 0) return 0;
        return (e.voterCandidateVotes[_voter][_candidateId] * 100) / voterTotal;
    }

    // Retorna a lista de candidatos concorrendo em uma eleição, dado seu ID
    function getCandidates(uint256 _electionId) public view returns (Candidate[] memory) {
        Election storage e = elections[_electionId];
        uint256 numCandidates = e.candidateCount;
        Candidate[] memory candidatesArray = new Candidate[](numCandidates);
        for (uint256 i = 0; i < numCandidates; i++) {
            uint256 candidateId = e.candidateIds[i];
            candidatesArray[i] = e.candidates[candidateId];
        }
        return candidatesArray;
    }

    // Dado o ID de uma eleição, retorna nome, se iniciou, se já fechou e o total de votos enviados
    function getElection(uint256 _electionId) public view returns (string memory, bool, bool, uint256) {
        Election storage e = elections[_electionId];
        return (e.name, e.started, e.closed, e.totalVotes);
    }

    // Retorna o nome de um candidato dado o ID do candidato e o ID da eleição o qual ele concorre
    function getCandidateName(uint256 _electionId, uint256 _candidateId) public view returns (string memory) {
        Election storage e = elections[_electionId];
        return e.candidates[_candidateId].name;
    }
}
