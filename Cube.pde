import java.util.LinkedList;
import java.util.Collections;

class Cube{
  int cubeSize;
  Block[] blocks;
  Axis axis;
  HashMap<String, PieceGroup> blockGroups = new HashMap<String, PieceGroup>();
  ArrayList<String> displayOrder = new ArrayList<String>();
  ArrayList<HashMap<String, PieceGroup>> groupStages = new ArrayList<HashMap<String, PieceGroup>>();
  LinkedList<Moves> moveQueue = new LinkedList<Moves>();
  int moveAnimationCounter = 0;
  String currMove = " ";
  PVector[] originalBlockDisps;
  boolean readyToTurn = false;
  Turn currentTurn;
  
  Cube(int size, int blockLength){
    cubeSize = size;
    axis = new Axis(center, size*blockLength + 80);
    blocks = new Block[size*size*size];
    originalBlockDisps = getNumbers(size);
    
    for(int i = 0; i < originalBlockDisps.length; i++){
      blocks[i] = new Block(center, blockLength, originalBlockDisps[i].copy());
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
    generateDisplayOrder();
  }
  
  String getFacesToShow(Block b){
    String res = "";
    ArrayList<String> faces = new ArrayList<String>();
    faces.addAll(Arrays.asList("F", "B", "U", "D", "L", "R"));
    for(String s: b.neighbors) faces.remove(s);
    for(String s: faces) res += s;
    return res;
  }
  
  void removeNeighbors(Block block, PVector disps, int size){
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
  
  void show(){
    if(!readyToTurn){
      for(String g: displayOrder){ 
        blockGroups.get(g).drawBlocks(this);
      }
    }
    else{
      println(getDisplayOrderGroups());
      for(int idx: getDisplayOrderGroups()){
        switch(idx){
            case 0:
              stroke(255, 0, 0);
              break;
            case 1:
              stroke(0, 255, 0);
              break;
            case 2:
              stroke(0, 0, 255);
              break;
        }
        for(String g: displayOrder){
          if(groupStages.get(idx).containsKey(g)){
            groupStages.get(idx).get(g).drawBlocks(this);
          }
        }
      }
    }
    axis.show();
  }
  
  void transform(char direction, int amount){
    for(Block b: blocks){
      b.transform(direction, amount);
    }
    
    axis.transform(direction, amount);
  }
  
  void updateMoves(){
    if(!Moves.getAllFaces().contains(currMove) && moveQueue.size() > 0){
      currMove = moveQueue.removeFirst().name();
    }
    if(Moves.getAllFaces().contains(currMove)){
      if(moveAnimationCounter < 90){
        moveAnimationCounter++;
        if(!readyToTurn){
          setUpBlocksToTurn(Moves.valueOf(currMove), 1);
        }
        turnFace(Moves.valueOf(currMove));
      }else{
        moveAnimationCounter = 0;
        shuffleBlocks();
        currMove = " ";
      }
    }
  }
  
  void updateState(char direction, int amount){
    for(Block b: blocks){
      b.transform(direction, amount);
      b.updateQXYZ(direction, amount);
    }
    axis.updateQXYZ(direction, amount);
    generateDisplayOrder();
  }
    
  void reset(){    
    for(int i = 0; i < originalBlockDisps.length; i++){
      blocks[i] = new Block(center, cubeSize, originalBlockDisps[i].copy());
      removeNeighbors(blocks[i], originalBlockDisps[i], size);
      
      String facesToShow = getFacesToShow(blocks[i]);
      blockGroups.get(facesToShow).addBlockIdx(i);
    }
    
    axis.reset();
  }
  
  PVector[] getNumbers(int base){
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
  
  void toggleMovingBlock(int index, boolean state){
    if(index < 0 || index >= blocks.length) return;    
    blocks[index].isMoving = state;
  }
  
  void setUpBlocksToTurn(Moves faceToTurn, int layer){
    if(layer < 0) layer = 0;
    if(layer >= cubeSize) layer = cubeSize - 1;
    currentTurn = new Turn(cubeSize, layer, faceToTurn);
    
    for(int r = 0; r < cubeSize; r++){
      for(int i = 0; i < cubeSize; i++){
        int index = currentTurn.d*currentTurn.cd + r*currentTurn.cr + i*currentTurn.ci;
        toggleMovingBlock(index, true);
      }
    }
    generateGroups(faceToTurn, layer);
    readyToTurn = true;
  }
  
  void turnFace(Moves faceToTurn){
    if(!readyToTurn) return;
    currentTurn.setAxis(faceToTurn, axis);
  
    for(int r = 0; r < cubeSize; r++){
      for(int i = 0; i < cubeSize; i++){
        int index = currentTurn.d*currentTurn.cd + r*currentTurn.cr + i*currentTurn.ci;
        blocks[index].updateQAroundAxis(currentTurn.axisOfRotation, 1);
        //blocks[index].toggleFacesToShow(turn.oppFace, 0);
        //blocks[index].showFace(Moves.valueOf(turn.oppFace));
        //blocks[index + turn.diff].toggleFacesToShow(turn.faceToTurn, 0);
        //blocks[index + turn.diff].showFace(Moves.valueOf(turn.faceToTurn));
      }
    }
  }
  
  void shuffleBlocks(){
    int[][] initPosArr = new int[cubeSize][cubeSize];
    
    for(int r = 0; r < cubeSize; r++){
      for(int i = 0; i < cubeSize; i++){
        int dIdx = currentTurn.d * currentTurn.cd;
        int rIdx = currentTurn.rInv ? (cubeSize - r - 1)* currentTurn.cr : r* currentTurn.cr;
        int iIdx = currentTurn.iInv ? (cubeSize - i - 1)* currentTurn.ci : i* currentTurn.ci;
        
        initPosArr[r][i] = dIdx + rIdx + iIdx;
      }
    }
    
    int[][] arrTranspose = new int[cubeSize][cubeSize];
    int[][] arrVFlipped = new int[cubeSize][cubeSize];
    
    for(int i = 0; i < cubeSize; i++){
      for(int j = 0; j < cubeSize; j++){
        arrTranspose[i][j] = initPosArr[j][i];
      }
    }
    
    for(int i = 0; i < cubeSize; i++){
      for(int j = 0; j < cubeSize; j++){
        arrVFlipped[i][j] = arrTranspose[i][cubeSize - j - 1];
      }
    }
    
    Block[][] blockArr = new Block[cubeSize][cubeSize];
    
    for(int i = 0; i < cubeSize; i++){
      for(int j = 0; j < cubeSize; j++){
        blockArr[i][j] = blocks[arrVFlipped[i][j]];
        toggleMovingBlock(arrVFlipped[i][j], false);
      }
    }
    
    for(int i = 0; i < cubeSize; i++){
      for(int j = 0; j < cubeSize; j++){
        blocks[initPosArr[i][j]] = blockArr[i][j];
      }
    }
    
    currentTurn = null;
    readyToTurn = false;
  }
  
  void addMove(Moves m){
    moveQueue.add(m);
    println(moveQueue);
  }
  
  void generateDisplayOrder(){
    HashMap<String, PieceGroup> blockGroupsCopy = new HashMap<String, PieceGroup>();
    for(PieceGroup g: blockGroups.values()){
      //g.flipAll(false);
      g.setPosition(this);
      blockGroupsCopy.put(g.getFacesAsString(), g);
    }
    ArrayList<String> res = new ArrayList<String>();
    
    while(blockGroupsCopy.size() > 0){
      PieceGroup currGroup = new PieceGroup(PieceType.Internal, null);
      for(String s: blockGroupsCopy.keySet()){
        if(isVectorFurther(blockGroupsCopy.get(s).position, currGroup.position, marginOfErrors[cubeSize - 1])){
          currGroup = blockGroupsCopy.get(s);
        }
      }
      res.add(currGroup.getFacesAsString());
      blockGroupsCopy.remove(currGroup.getFacesAsString());
    }
    
    displayOrder = res;
  }
  
  ArrayList<Integer> getDisplayOrderGroups(){
    ArrayList<Integer> groupOrder = new ArrayList<Integer>();
    //HashMap<Integer, PVector> groupListDepth = new HashMap<Integer, PVector>();
    //HashMap<Integer, PVector> groupListDistance = new HashMap<Integer, PVector>();
    ArrayList<ArrayList<Integer>> groupsToCompare = currentTurn.generateGroupList(this);
    HashMap<Integer, PVector> groupLists = new HashMap<Integer, PVector>();
    
    //for(int i = 0; i < groupDepthsToCompare.size(); i++){
    //  PVector sumPV = new PVector(0, 0, 0);
    //  for(PieceGroup group: groupDepthsToCompare.get(i)){
    //    //println(group.groupType.name() + group.getFacesAsString() + group.indexList);
    //    PVector temp = group.getSumOfPositions(this);
    //    sumPV.add(temp);
    //    //println(i + "A" + temp);
    //  }
    //  groupListDepth.put(i, sumPV);
    //}
    
    for(int i = 0; i < groupsToCompare.size(); i++){
      PVector sumPV = new PVector(0, 0, 0);
      for(int p: groupsToCompare.get(i)){
        //println(group.groupType.name() + group.getFacesAsString() + group.indexList);
        sumPV.add(blocks[p].distToCenter.copy());
        //println(i + "A" + temp);
      }
      sumPV.div(groupsToCompare.get(i).size());
      groupLists.put(i, sumPV);
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
    
    //groupListDistance.put(0, groupDistancesToCompare.get(0));
    //groupListDistance.put(1, groupDistancesToCompare.get(1));
    //if(groupDepthsToCompare.size() > 2){
    //  groupListDistance.put(2, groupDistancesToCompare.get(2));
    //}
    //for(int i: groupListDepth.keySet()){
    //  PVector p2 = groupListDepth.get(i);
    //  println(i + " " + p2);
    //}
    //println(groupListDepth + "\n" + groupListDistance);
    //while(groupListDepth.size() > 0){
    //  PVector closestDepthP = new PVector(0, 0, Integer.MAX_VALUE);
    //  PVector furthestDistanceP = new PVector(0, 0, 0);
    //  int index = 0;
    //  for(int i: groupListDepth.keySet()){
    //    PVector currDepthP = groupListDepth.get(i);
    //    PVector currDistanceP = groupListDistance.get(i);
    //    if(isVectorFurtherWithDifferentVectors(currDepthP, closestDepthP, 
    //                                           currDistanceP, furthestDistanceP, 
    //                                           marginOfErrors[cubeSize - 1])){
    //      closestDepthP = currDepthP;
    //      furthestDistanceP = currDistanceP;
    //      index = i;
    //    }
    //  }
    //  groupOrder.add(index);
    //  groupListDepth.remove(index);
    //  groupListDistance.remove(index);
      //println(groupListDepth);
    //}
    
    
    return groupOrder;
  }
  
  void generateGroups(Moves face, int layer){
    /*
    Group 0: Groups that match the face
    Group 1: Groups that don't match the face(s)
    Group 2: Groups that match the opposite face (slice turns only)
    */
    
    //groupDepthsToCompare.clear();
    groupStages.clear();

    //groupDistancesToCompare.addAll(Arrays.asList(new PVector(Integer.MAX_VALUE, Integer.MAX_VALUE, 0),
    //                                             new PVector(Integer.MAX_VALUE, Integer.MAX_VALUE, 0)));
    //if(layer > 0) groupDistancesToCompare.add(new PVector(Integer.MAX_VALUE, Integer.MAX_VALUE, 0));
    
    //groupDepthsToCompare.addAll(Arrays.asList(new ArrayList<PieceGroup>(), 
    //                                          new ArrayList<PieceGroup>()));
    //if(layer > 0) groupDepthsToCompare.add(new ArrayList<PieceGroup>());
    
    HashMap<String, PieceGroup> groupMatchesFace = new HashMap<String, PieceGroup>();
    HashMap<String, PieceGroup> groupDoesntMatchBothFaces = new HashMap<String, PieceGroup>();
    HashMap<String, PieceGroup> groupMatchesOppositeFace = new HashMap<String, PieceGroup>();
    
    for(String s: blockGroups.keySet()){
      PieceGroup currGroup = (PieceGroup) blockGroups.get(s).clone();
      if(s.contains(face.name())){ //matches face
        groupMatchesFace.put(s, currGroup);
        //groupDepthsToCompare.get(0).add(currGroup);
      }
      else if(layer > 0 && s.contains(Moves.getOppositeFace(face.name()))){ //matches opposite face
        groupMatchesOppositeFace.put(s, currGroup);
        //groupDepthsToCompare.get(2).add(currGroup);
      }
      else{ //doesn't match either face
        //println(blockGroups.get(s).indexList);
        groupMatchesFace.put(s, (PieceGroup) currGroup.clone());
        groupMatchesFace.get(s).filterNonMovingBlocks(this, '<', currentTurn);
        //groupDepthsToCompare.get(0).add(groupMatchesFace.get(s));
        //println("M" + groupMatchesFace.get(s).indexList);
        if(groupMatchesFace.get(s).indexList.size() == 0){
          groupMatchesFace.remove(s);
        }else{
          //PVector vectorToConsider = groupMatchesFace.get(s).getClosestToCenter(this);
          //if(get2DLength(vectorToConsider) < get2DLength(groupDistancesToCompare.get(0))){
          //  groupDistancesToCompare.set(0, vectorToConsider);
          //}
        }
        
        groupDoesntMatchBothFaces.put(s, (PieceGroup) currGroup.clone());
        groupDoesntMatchBothFaces.get(s).filterNonMovingBlocks(this, '=', currentTurn);
        //groupDepthsToCompare.get(1).add(groupDoesntMatchBothFaces.get(s));
        //println("D" + groupDoesntMatchBothFaces.get(s).indexList);
        if(groupDoesntMatchBothFaces.get(s).indexList.size() == 0){
          groupDoesntMatchBothFaces.remove(s);
        }else{
          //PVector vectorToConsider = groupDoesntMatchBothFaces.get(s).getClosestToCenter(this);
          //if(get2DLength(vectorToConsider) < get2DLength(groupDistancesToCompare.get(1))){
          //  groupDistancesToCompare.set(1, vectorToConsider);
          //}
        }

        if(layer > 0){
          groupMatchesOppositeFace.put(s, (PieceGroup) currGroup.clone());
          groupMatchesOppositeFace.get(s).filterNonMovingBlocks(this, '>', currentTurn);
          //groupDepthsToCompare.get(2).add(groupMatchesOppositeFace.get(s));
          //println("O" + groupMatchesOppositeFace.get(s).indexList);
          if(groupMatchesOppositeFace.get(s).indexList.size() == 0){
            groupMatchesOppositeFace.remove(s);
          }else{
            //PVector vectorToConsider = groupMatchesOppositeFace.get(s).getClosestToCenter(this);
            //if(get2DLength(vectorToConsider) < get2DLength(groupDistancesToCompare.get(2))){
            //  groupDistancesToCompare.set(2, vectorToConsider);
            //}
          }
        }
      }
    }
    
    groupStages.addAll(Arrays.asList(groupMatchesFace, groupDoesntMatchBothFaces));
    if(layer > 0) groupStages.add(groupMatchesOppositeFace);
  }
}
