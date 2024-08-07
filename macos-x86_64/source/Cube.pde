class Cube{
  int cubeSize;
  Block[] blocks;
  Axis axis;
  HashMap<String, PieceGroup> blockGroups = new HashMap<String, PieceGroup>();
  ArrayList<String> displayOrder = new ArrayList<String>();
  ArrayList<HashMap<String, PieceGroup>> groupStages = new ArrayList<HashMap<String, PieceGroup>>();
  int moveAnimationCounter = 0;
  PVector[] originalBlockDisps;
  boolean readyToTurn = false;
  LinkedList<Turn> turnQueue = new LinkedList<Turn>();
  Turn currentTurn;
  boolean fillBlock;
  
  public Cube(int size, int blockLength, boolean drawFill){
    cubeSize = size;
    fillBlock = drawFill;
    axis = new Axis(center, size*blockLength + 80);
    blocks = new Block[size*size*size];
    originalBlockDisps = getNumbers(size);
    
    for(int i = 0; i < originalBlockDisps.length; i++){
      blocks[i] = new Block(center, blockLength, originalBlockDisps[i].copy(), fillBlock);
      removeNeighbors(blocks[i], originalBlockDisps[i], size);
      
      String facesToShow = getFacesToShow(blocks[i]);
      if(!blockGroups.containsKey(facesToShow)){
        String[] faceArray = new String[0];
        if(facesToShow != "") faceArray = facesToShow.split("");
        blockGroups.put(facesToShow, new PieceGroup(PieceType.getType(facesToShow), faceArray));
      }
      blockGroups.get(facesToShow).addBlockIdx(i);
    }
    
    for(String s: blockGroups.keySet()) blockGroups.get(s).setPosition(this);
    generateDisplayOrder(blockGroups);
  }
  
  private String getFacesToShow(Block b){
    String res = "";
    ArrayList<String> faces = new ArrayList<String>();
    faces.addAll(Arrays.asList("F", "B", "U", "D", "L", "R"));
    for(String s: b.neighbors) faces.remove(s);
    for(String s: faces) res += s;
    return res;
  }
  
  private void removeNeighbors(Block block, PVector disps, int size){
    float offset = size/2;
    if(size % 2 == 0) offset -= 0.5;
    //X+ Face (R)
    if(disps.x == offset) block.removeNeighbor("R");
    //X- Face(L)
    if(disps.x == -1*offset) block.removeNeighbor("L");
    //Y+ Face (D)
    if(disps.y == offset) block.removeNeighbor("D");
    //Y- Face (U)
    if(disps.y == -1*offset) block.removeNeighbor("U");
    //Z+ Face (F)
    if(disps.z == offset) block.removeNeighbor("F");
    //Z- Face (B)
    if(disps.z == -1*offset) block.removeNeighbor("B");
  }
  
  public void show(){
    if(!readyToTurn){
      for(String g: displayOrder){ 
        blockGroups.get(g).drawBlocks(this, fillBlock);
      }
    }
    else{
      for(int idx: getDisplayOrderGroups()){
        generateDisplayOrder(groupStages.get(idx));
        for(String g: displayOrder){
          if(groupStages.get(idx).containsKey(g)){
            groupStages.get(idx).get(g).drawBlocks(this, fillBlock);
          }
        }
      }
    }
    //axis.show();
  }
  
  public void transform(char direction, int amount){
    for(Block b: blocks) b.transform(direction, amount);
    axis.transform(direction, amount);
  }
  
  public void updateMoves(){
    if(turnQueue.size() > 0 && currentTurn == null){
      currentTurn = turnQueue.removeFirst();
    }
    if(currentTurn != null){
      if(moveAnimationCounter < currentTurn.turnCount*90){
        moveAnimationCounter += abs(currentTurn.directionAmount);
        if(!readyToTurn){
          setUpBlocksToTurn(Moves.valueOf(currentTurn.faceToTurn), currentTurn.d);
        }
        turnFace();
      }else{
        moveAnimationCounter = 0;
        shuffleBlocks();
      }
    }
  }
  
  public void updateState(char direction, int amount){
    for(Block b: blocks){
      b.transform(direction, amount);
      b.updateQXYZ(direction, amount);
    }
    axis.updateQXYZ(direction, amount);
    generateDisplayOrder(blockGroups);
  }
    
  public void reset(){    
    for(int i = 0; i < originalBlockDisps.length; i++){
      blocks[i] = new Block(center, cubeSize, originalBlockDisps[i].copy(), fillBlock);
      removeNeighbors(blocks[i], originalBlockDisps[i], size);
      
      String facesToShow = getFacesToShow(blocks[i]);
      blockGroups.get(facesToShow).addBlockIdx(i);
    }
    
    axis.reset();
  }
  
  public PVector[] getNumbers(int base){
    if(base < 1) return null;
    ArrayList<PVector> disps = new ArrayList<PVector>();
    int offset = (int)Math.floor(base/2.0f);
    int adjustedBase = base + ((base + 1) % 2);
    for(int i = 0; i < adjustedBase; i++){
      for(int j = 0; j < adjustedBase; j++){
        for(int k = 0; k < adjustedBase; k++){
          disps.add(new PVector(k - offset, j - offset, i - offset));
        }
      }
    }
    
    PVector[] result = new PVector[base*base*base];
    int counter = 0;
    for(int i = 0; i < disps.size(); i++){
      if((disps.get(i).x == 0.0 || disps.get(i).y == 0.0 || disps.get(i).z == 0.0) && base % 2 == 0){
        continue;
      }
      result[counter] = disps.get(i);
      if(base % 2 == 0){
        PVector translationFactor = disps.get(i).copy();
        //Scale everything down to either 0.5 or -0.5
        translationFactor.x /= -2*abs(translationFactor.x);
        translationFactor.y /= -2*abs(translationFactor.y);
        translationFactor.z /= -2*abs(translationFactor.z);
        //add translationFactor to result
        result[counter].add(translationFactor);
      }
      counter++;
    }
    return result;
  }
  
  public void toggleMovingBlock(int index, boolean state){
    if(index < 0 || index >= blocks.length) return;    
    blocks[index].isMoving = state;
  }
  
  private void setUpBlocksToTurn(Moves faceToTurn, int layer){
    if(layer < 0) layer = 0;
    if(layer >= cubeSize) layer = cubeSize - 1;

    for(int r = 0; r < cubeSize; r++){
      for(int i = 0; i < cubeSize; i++){
        int index = currentTurn.d*currentTurn.cd + r*currentTurn.cr + i*currentTurn.ci;
        toggleMovingBlock(index, true);
        
        blocks[index].setFaceState(Moves.valueOf(currentTurn.oppFace), 0);
        if(cubeSize > 1){
          blocks[index + currentTurn.diff].setFaceState(Moves.valueOf(currentTurn.faceToTurn), 0);
        }
        if(!isLayerOnEdge(currentTurn.d, currentTurn.cubeSize)){
          blocks[index].setFaceState(Moves.valueOf(currentTurn.faceToTurn), 0);
          blocks[index - currentTurn.diff].setFaceState(Moves.valueOf(currentTurn.oppFace), 0);
        }
      }
    }
    generateGroups(faceToTurn, layer);
    readyToTurn = true;
  }
  
  private void turnFace(){
    if(!readyToTurn) return;
    currentTurn.setAxis(axis);
  
    for(int r = 0; r < cubeSize; r++){
      for(int i = 0; i < cubeSize; i++){
        int index = currentTurn.d*currentTurn.cd + r*currentTurn.cr + i*currentTurn.ci;
        blocks[index].updateQAroundAxis(currentTurn.axisOfRotation, currentTurn.directionAmount);
      }
    }
  }
  
  private int[][] rotateIndexes(int[][] initPosArr, boolean isClockwise){
    int[][] arrTranspose = new int[cubeSize][cubeSize];
    int[][] arrResFlipped = new int[cubeSize][cubeSize];
    
    for(int i = 0; i < cubeSize; i++){
      for(int j = 0; j < cubeSize; j++){
        arrTranspose[i][j] = initPosArr[j][i];
      }
    }
    if(isClockwise){
      for(int i = 0; i < cubeSize; i++){
        for(int j = 0; j < cubeSize; j++){
          arrResFlipped[i][j] = arrTranspose[i][cubeSize - j - 1];
        }
      }
    }else{
      for(int i = 0; i < cubeSize; i++){
        for(int j = 0; j < cubeSize; j++){
          arrResFlipped[i][j] = arrTranspose[cubeSize - i - 1][j];
        }
      }
    }
    return arrResFlipped;
  }
  
  private void shuffleBlocks(){
    int[][] initPosArr = new int[cubeSize][cubeSize];
    
    for(int r = 0; r < cubeSize; r++){
      for(int i = 0; i < cubeSize; i++){
        int dIdx = currentTurn.d * currentTurn.cd;
        int rIdx = currentTurn.rInv ? (cubeSize - r - 1)* currentTurn.cr : r* currentTurn.cr;
        int iIdx = currentTurn.iInv ? (cubeSize - i - 1)* currentTurn.ci : i* currentTurn.ci;
        
        initPosArr[r][i] = dIdx + rIdx + iIdx;
      }
    }
    
    int[][] rotatedArr = rotateIndexes(initPosArr, currentTurn.directionAmount > 0);
    if(currentTurn.turnCount == 2) rotatedArr = rotateIndexes(rotatedArr, currentTurn.directionAmount > 0);
    
    Block[][] blockArr = new Block[cubeSize][cubeSize];
    
    for(int i = 0; i < cubeSize; i++){
      for(int j = 0; j < cubeSize; j++){
        blockArr[i][j] = blocks[rotatedArr[i][j]];
        toggleMovingBlock(rotatedArr[i][j], false);
      }
    }
    
    for(int i = 0; i < cubeSize; i++){
      for(int j = 0; j < cubeSize; j++){
        int index = initPosArr[i][j];
        blocks[index] = blockArr[i][j];
        blocks[index].applyTurnRotation(currentTurn);
        
        blocks[index].setFaceState(Moves.valueOf(currentTurn.oppFace), -1);
        if(cubeSize > 1){
          blocks[index + currentTurn.diff].setFaceState(Moves.valueOf(currentTurn.faceToTurn), -1);
        }
        if(!isLayerOnEdge(currentTurn.d, currentTurn.cubeSize)){
          blocks[index].setFaceState(Moves.valueOf(currentTurn.faceToTurn), -1);
          blocks[index - currentTurn.diff].setFaceState(Moves.valueOf(currentTurn.oppFace), -1);
        }
      }
    }
    
    currentTurn = null;
    readyToTurn = false;
  }
  
  public void addMove(Moves m, int currDepth, boolean isTurnClockwise, int count){
    turnQueue.add(new Turn(cubeSize, currDepth, m, isTurnClockwise, count));
  }
  
  public void generateDisplayOrder(HashMap<String, PieceGroup> groupMap){
    HashMap<String, PieceGroup> groupMapCopy = new HashMap<String, PieceGroup>();
    for(PieceGroup g: groupMap.values()){
      g.setPosition(this);
      groupMapCopy.put(g.getFacesAsString(), g);
    }
    ArrayList<String> res = new ArrayList<String>();
    
    while(groupMapCopy.size() > 0){
      PieceGroup currGroup = new PieceGroup(PieceType.Internal, null);
      for(String s: groupMapCopy.keySet()){
        if(isVectorFurther(groupMapCopy.get(s).position, currGroup.position, marginOfErrors[cubeSize - 1])){
          currGroup = groupMapCopy.get(s);
        }
      } 
      res.add(currGroup.getFacesAsString());
      groupMapCopy.remove(currGroup.getFacesAsString());
    }
    
    displayOrder = res;
  }
  
  private ArrayList<Integer> getDisplayOrderGroups(){
    ArrayList<Integer> groupOrder = new ArrayList<Integer>();
    ArrayList<ArrayList<Integer>> groupsToCompare = currentTurn.generateGroupList(this);
    HashMap<Integer, PVector> groupLists = new HashMap<Integer, PVector>();
    
    for(int i = 0; i < groupsToCompare.size(); i++){
      PVector closestP = new PVector(Integer.MAX_VALUE, Integer.MAX_VALUE, Integer.MIN_VALUE);
      
      for(int p = 0; p < groupsToCompare.get(i).size(); p += cubeSize % 2){
        if(cubeSize % 2 == 0){
          PVector currP = new PVector(0, 0, 0);
          for(int j = 0; j < 4; j++, p++){
            currP.add(blocks[groupsToCompare.get(i).get(p)].distToCenter.copy());
          }
          if(isVectorFurther(closestP, currP, marginOfErrors[cubeSize - 1])){
            closestP = currP;
          }
        }else{
          if(isVectorFurther(closestP, blocks[groupsToCompare.get(i).get(p)].distToCenter.copy(), marginOfErrors[cubeSize - 1])){
            closestP = blocks[groupsToCompare.get(i).get(p)].distToCenter.copy();
          }
        }
      }
      groupLists.put(i, closestP);
    }
        
    while(groupLists.size() > 0){
      PVector currFurthestPoint = new PVector(0, 0, Integer.MAX_VALUE);
      int index = 0;
      for(int i: groupLists.keySet()){
        PVector currP = groupLists.get(i);
        if(isVectorFurther(currP, currFurthestPoint, marginOfErrors[cubeSize - 1])){
          currFurthestPoint = currP;
          index = i;
        }
      }
      groupOrder.add(index);
      groupLists.remove(index);
    }
    return groupOrder;
  }
  
  private void generateGroups(Moves face, int layer){
    /*
    Group 0: Groups that match the face
    Group 1: Groups that don't match the face(s)
    Group 2: Groups that match the opposite face (slice turns only)
    */
    groupStages.clear();
    
    HashMap<String, PieceGroup> groupMatchesFace = new HashMap<String, PieceGroup>();
    HashMap<String, PieceGroup> groupDoesntMatchBothFaces = new HashMap<String, PieceGroup>();
    HashMap<String, PieceGroup> groupMatchesOppositeFace = new HashMap<String, PieceGroup>();
    
    for(String s: blockGroups.keySet()){
      PieceGroup currGroup = (PieceGroup) blockGroups.get(s).clone();
      if(s.contains(face.name())){ //matches face
        groupMatchesFace.put(s, currGroup);
      }
      else if(!isLayerOnEdge(layer, cubeSize) && s.contains(Moves.getOppositeFace(face.name()))){ //matches opposite face
        groupMatchesOppositeFace.put(s, currGroup);
      }
      else{ //doesn't match either face
        if(layer > 0 && layer < cubeSize - 1){
          groupMatchesFace.put(s, (PieceGroup) currGroup.clone());
          groupMatchesFace.get(s).filterNonMovingBlocks(this, '<', currentTurn);
          if(groupMatchesFace.get(s).indexList.size() == 0) groupMatchesFace.remove(s);
        }
        
        groupDoesntMatchBothFaces.put(s, (PieceGroup) currGroup.clone());
        groupDoesntMatchBothFaces.get(s).filterNonMovingBlocks(this, '=', currentTurn);
        if(groupDoesntMatchBothFaces.get(s).indexList.size() == 0) groupDoesntMatchBothFaces.remove(s);

        if(!isLayerOnEdge(layer, cubeSize)){
          groupMatchesOppositeFace.put(s, (PieceGroup) currGroup.clone());
          groupMatchesOppositeFace.get(s).filterNonMovingBlocks(this, '>', currentTurn);
          if(groupMatchesOppositeFace.get(s).indexList.size() == 0) groupMatchesOppositeFace.remove(s);
        }
      }
    }
    
    groupStages.addAll(Arrays.asList(groupMatchesFace, groupDoesntMatchBothFaces));
    if(layer > 0) groupStages.add(groupMatchesOppositeFace);
  }
}
